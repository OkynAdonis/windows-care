# Etat limite aux parametres geres par Windows Care. Charge par le moteur.
function Get-PrivacySettings {
    @(
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection','AllowTelemetry',0),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection','DisableOneSettingsDownloads',1),
        @('HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows','CEIPEnable',0),
        @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection','AllowTelemetry',0),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting','Disabled',1),
        @('HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting','Disabled',1)
    ) | ForEach-Object { [pscustomobject]@{Path=$_[0]; Name=$_[1]; Value=$_[2]} }
}
function Get-SearchSettings {
    foreach ($name in @('ConnectedSearchUseWeb','DisableWebSearch','AllowCloudSearch','AllowCortana')) {
        [pscustomobject]@{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name=$name; Value=[int]($name -eq 'DisableWebSearch')}
    }
    [pscustomobject]@{Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name='BingSearchEnabled'; Value=0}
}
function Get-PrivacyTasks {
    $paths = @(
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\Autochk\Proxy',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Feedback\Siuf\DmClient',
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
    )
    Get-ScheduledTask -ErrorAction Stop | Where-Object { ($_.TaskPath + $_.TaskName) -in $paths }
}
function New-StateBackup {
    param([ValidateSet('Privacy','Search','DNS','Power')][string]$Category,
          [object]$Adapter)
    if ($script:Simulation) { return }
    $path = Join-Path $script:BackupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
    $state = [ordered]@{SchemaVersion=2; Category=$Category; CreatedAt=(Get-Date).ToString('o'); Computer=$env:COMPUTERNAME; UserSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value; Complete=$false}
    try {
        if ($Category -in @('Privacy','Search')) {
            $settings = if ($Category -eq 'Privacy') { Get-PrivacySettings } else { Get-SearchSettings }
            $state.Registry = @(foreach ($setting in $settings) {
                $exists = $false; $value = $null; $kind = 'DWord'
                if (Test-Path -LiteralPath $setting.Path) {
                    $key = Get-Item -LiteralPath $setting.Path -ErrorAction Stop
                    try {
                        $exists = $setting.Name -in $key.GetValueNames()
                        if ($exists) { $value=$key.GetValue($setting.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); $kind=[string]$key.GetValueKind($setting.Name) }
                    } finally { $key.Close() }
                }
                [pscustomobject]@{Path=$setting.Path; Name=$setting.Name; Exists=$exists; Value=$value; Kind=$kind}
            })
        }
        if ($Category -eq 'Privacy') {
            $state.Services = @(Get-Service -ErrorAction Stop | Where-Object Name -in @('DiagTrack','diagsvc','WerSvc','wercplsupport') | ForEach-Object {
                $serviceKey = Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $_.Name) -ErrorAction Stop
                [pscustomobject]@{Name=$_.Name; StartType=[string]$_.StartType; Status=[string]$_.Status; DelayedAutoStart=$serviceKey.DelayedAutoStart}
            })
            $state.Tasks = @(Get-PrivacyTasks | Select-Object TaskName,TaskPath,@{N='Enabled';E={$_.Settings.Enabled}})
        }
        if ($Category -eq 'DNS') {
            if (-not $Adapter) { throw 'Interface DNS manquante.' }
            $guid = ([guid]$Adapter.InterfaceGuid).ToString('B')
            $state.AdapterGuid = $guid
            $state.DNS = @(foreach ($family in @('IPv4','IPv6')) {
                $branch = if ($family -eq 'IPv4') { 'Tcpip' } else { 'Tcpip6' }
                $key = Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$branch\Parameters\Interfaces\$guid" -ErrorAction Stop
                $dns = Get-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily $family -ErrorAction Stop
                [pscustomobject]@{Family=$family; Automatic=[string]::IsNullOrWhiteSpace([string]$key.NameServer); Servers=@($dns.ServerAddresses)}
            })
        }
        if ($Category -eq 'Power') { $state.PowerGuid = Get-ActivePowerPlanGuid; if (-not $state.PowerGuid) { throw 'Plan actif introuvable.' } }
        $state.Complete = $true
        [pscustomobject]$state | Export-Clixml -LiteralPath (Join-Path $path 'state.xml') -ErrorAction Stop
        [pscustomobject]@{SchemaVersion=2; Category=$Category; Complete=$true; CreatedAt=$state.CreatedAt} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $path 'manifest.json') -Encoding UTF8
        Write-Log "Sauvegarde $Category creee : $path" 'OK'
        return $path
    } catch { throw "Sauvegarde $Category incomplete, action annulee : $($_.Exception.Message)" }
}
function Restore-State {
    $backup = Select-Backup
    if (-not $backup -or -not (Confirm-Action "Restaurer la sauvegarde $($backup.Name)")) { return }
    Invoke-Action "Restauration de $($backup.Name)" {
        $file = Join-Path $backup.FullName 'state.xml'
        if (-not (Test-Path -LiteralPath $file)) { throw 'Ancienne sauvegarde partielle : restauration automatique non prise en charge. Conserver les fichiers pour une restauration manuelle.' }
        $state = Import-Clixml -LiteralPath $file -ErrorAction Stop
        if ($state.SchemaVersion -ne 2 -or -not $state.Complete -or $state.Category -notin @('Privacy','Search','DNS','Power')) { throw 'Format de sauvegarde invalide ou incomplet.' }
        if ($state.Computer -ne $env:COMPUTERNAME -or $state.UserSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) { throw 'Restaurer sur le meme ordinateur et avec le meme compte Windows.' }
        $adapter = $null
        if ($state.Category -eq 'DNS') {
            $adapter = @(Get-NetAdapter -ErrorAction Stop | Where-Object { [guid]$_.InterfaceGuid -eq [guid]$state.AdapterGuid })
            if ($adapter.Count -ne 1) { throw 'Interface reseau originale introuvable.' }
            $adapter = $adapter[0]
        }
        # Sauvegarder l etat actuel avant la premiere ecriture de restauration.
        New-StateBackup -Category $state.Category -Adapter $adapter | Out-Null
        foreach ($entry in @($state.Registry)) {
            if (-not $entry) { continue }
            $allowed = @(Get-PrivacySettings) + @(Get-SearchSettings)
            if (-not ($allowed | Where-Object { $_.Path -eq $entry.Path -and $_.Name -eq $entry.Name })) { throw 'Valeur de registre hors du perimetre Windows Care.' }
            if ($entry.Exists) {
                if (-not (Test-Path -LiteralPath $entry.Path)) { New-Item -Path $entry.Path -Force -ErrorAction Stop | Out-Null }
                New-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Value $entry.Value -PropertyType $entry.Kind -Force -ErrorAction Stop | Out-Null
            } elseif (Test-Path -LiteralPath $entry.Path) {
                $key = Get-Item -LiteralPath $entry.Path
                try { $present = $entry.Name -in $key.GetValueNames() } finally { $key.Close() }
                if ($present) { Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction Stop }
            }
        }
        foreach ($service in @($state.Services)) {
            if (-not $service) { continue }
            Set-Service -Name $service.Name -StartupType $service.StartType -ErrorAction Stop
            if ($null -ne $service.DelayedAutoStart) { Set-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $service.Name) -Name DelayedAutoStart -Value $service.DelayedAutoStart -ErrorAction Stop }
            if ($service.Status -eq 'Running') { Start-Service -Name $service.Name -ErrorAction Stop }
            elseif ($service.Status -eq 'Stopped') { Stop-Service -Name $service.Name -ErrorAction Stop }
        }
        foreach ($task in @($state.Tasks)) {
            if (-not $task) { continue }
            if ($task.Enabled) { Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null }
            else { Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null }
        }
        foreach ($dns in @($state.DNS)) {
            if (-not $dns) { continue }
            $target = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily $dns.Family -ErrorAction Stop
            if ($dns.Automatic) { $target | Set-DnsClientServerAddress -ResetServerAddresses -ErrorAction Stop }
            else { $target | Set-DnsClientServerAddress -ServerAddresses $dns.Servers -ErrorAction Stop }
        }
        if ($state.PowerGuid) { Invoke-NativeCommand 'powercfg.exe' @('-setactive',$state.PowerGuid) 'Restauration alimentation' | Out-Null }
    } | Out-Null
}
