# Diagnostics avances et export d assistance de Windows Care.

function Get-SafeDiagnosticValue {
    param([string]$Name,[scriptblock]$Action)
    try { return (& $Action) }
    catch { return [pscustomobject]@{Unavailable=$true;Name=$Name;Error=$_.Exception.Message} }
}

function Get-PendingRebootState {
    $reasons = [Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $reasons.Add('Maintenance des composants Windows') }
    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $reasons.Add('Windows Update') }
    try {
        $pending = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations
        if (@($pending).Count) { $reasons.Add('Operations sur des fichiers systeme') }
    } catch { }
    [pscustomobject]@{ Pending = ($reasons.Count -gt 0); Reasons = @($reasons) }
}

function Get-NetworkDiagnostic {
    $configurations = @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object IPv4Address)
    $dnsOk = $false
    $internetOk = $false
    $dnsDetail = 'Non teste'
    $internetDetail = 'Non teste'
    try {
        $answer = @(Resolve-DnsName 'www.microsoft.com' -Type A -DnsOnly -QuickTimeout -ErrorAction Stop)
        $dnsOk = @($answer | Where-Object IPAddress).Count -gt 0
        $dnsDetail = if ($dnsOk) { 'Resolution DNS reussie' } else { 'Aucune adresse IPv4 recue' }
    } catch { $dnsDetail = $_.Exception.Message }
    try {
        $internetOk = [bool](Test-NetConnection 'www.microsoft.com' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue)
        $internetDetail = if ($internetOk) { 'Connexion TCP 443 reussie' } else { 'Connexion TCP 443 impossible' }
    } catch { $internetDetail = $_.Exception.Message }
    [pscustomobject]@{
        Adapters = @($configurations | ForEach-Object {
            [pscustomobject]@{
                Name = $_.InterfaceAlias
                IPv4 = @($_.IPv4Address | ForEach-Object IPAddress)
                Gateway = @($_.IPv4DefaultGateway | ForEach-Object NextHop)
                DNS = @($_.DNSServer.ServerAddresses)
            }
        })
        DNS = [pscustomobject]@{ Success = $dnsOk; Detail = $dnsDetail }
        Internet = [pscustomobject]@{ Success = $internetOk; Detail = $internetDetail }
    }
}

function Get-WindowsUpdateDiagnostic {
    $services = foreach ($name in @('wuauserv','bits','cryptsvc')) {
        try { Get-Service -Name $name -ErrorAction Stop | Select-Object Name,Status,StartType }
        catch { [pscustomobject]@{Name=$name;Status='Indisponible';StartType='Indisponible'} }
    }
    $lastUpdates = try { @(Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 5 HotFixID,Description,InstalledOn) } catch { @() }
    [pscustomobject]@{ Services = @($services); Reboot = Get-PendingRebootState; LastUpdates = $lastUpdates }
}

function Get-DriverIssues {
    try {
        @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object ConfigManagerErrorCode -ne 0 | Select-Object Name,PNPClass,DeviceID,ConfigManagerErrorCode)
    } catch { throw "Diagnostic des pilotes indisponible : $($_.Exception.Message)" }
}

function Show-NetworkDiagnostic {
    Invoke-Action 'Diagnostic reseau par couches' -ReadOnly {
        $result = Get-NetworkDiagnostic
        $result.Adapters | Format-List Name,IPv4,Gateway,DNS
        Write-Host "DNS      : $($result.DNS.Success) - $($result.DNS.Detail)"
        Write-Host "Internet : $($result.Internet.Success) - $($result.Internet.Detail)"
    } | Out-Null
}

function Show-WindowsUpdateDiagnostic {
    Invoke-Action 'Diagnostic Windows Update' -ReadOnly {
        $result = Get-WindowsUpdateDiagnostic
        $result.Services | Format-Table -AutoSize
        Write-Host "Redemarrage en attente : $($result.Reboot.Pending)"
        if ($result.Reboot.Reasons.Count) { Write-Host "Raisons : $($result.Reboot.Reasons -join ', ')" }
        $result.LastUpdates | Format-Table -AutoSize
    } | Out-Null
}

function Show-DriverIssues {
    Invoke-Action 'Recherche des pilotes en erreur' -ReadOnly {
        $issues = @(Get-DriverIssues)
        if ($issues.Count) { $issues | Format-Table Name,PNPClass,ConfigManagerErrorCode -AutoSize }
        else { Write-Log 'Aucun peripherique avec un code erreur detecte.' 'OK' }
    } | Out-Null
}

function New-BatteryDiagnostic {
    Invoke-Action 'Creation du rapport batterie Windows' -ReadOnly {
        $battery = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
        if (-not $battery.Count) { throw 'Aucune batterie detectee sur cet ordinateur.' }
        $report = Join-Path $script:DataRoot "battery-$($script:Session).html"
        Invoke-NativeCommand 'powercfg.exe' @('/batteryreport','/output',$report) 'Rapport batterie' | Out-Null
        if (-not (Test-Path -LiteralPath $report)) { throw 'Windows n a pas produit le rapport batterie.' }
        Write-Log "Rapport batterie : $report" 'OK'
    } | Out-Null
}

function New-SystemRestorePoint {
    if (-not (Confirm-Action 'Creer un point de restauration Windows avant les prochaines modifications')) { return }
    Invoke-Action 'Creation du point de restauration Windows Care' {
        $command = Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue
        if (-not $command) { throw 'Checkpoint-Computer est indisponible sur cette edition de Windows.' }
        Checkpoint-Computer -Description "Windows Care $($script:Session)" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log 'Point de restauration demande a Windows. Verifier sa presence dans Protection du systeme.' 'OK'
    } | Out-Null
}

function New-SupportBundle {
    Invoke-Action 'Creation du dossier de support Windows Care' -ReadOnly {
        $folder = Join-Path $script:DataRoot "support-$($script:Session)"
        New-Item -ItemType Directory -Path $folder -ErrorAction Stop | Out-Null
        $os = Get-SafeDiagnosticValue 'Windows' { Get-CimInstance Win32_OperatingSystem -ErrorAction Stop | Select-Object Caption,Version,BuildNumber,OSArchitecture,LastBootUpTime }
        $computer = Get-SafeDiagnosticValue 'Ordinateur' { Get-CimInstance Win32_ComputerSystem -ErrorAction Stop | Select-Object Manufacturer,Model,@{N='MemoryGB';E={[math]::Round($_.TotalPhysicalMemory/1GB,1)}} }
        $disks = Get-SafeDiagnosticValue 'Disques' { @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | Select-Object DeviceID,@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}},@{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,1)}}) }
        $payload = [ordered]@{
            CreatedAt = (Get-Date).ToString('o')
            Computer = $computer
            Windows = $os
            Disks = $disks
            Health = Get-SafeDiagnosticValue 'Sante' { Get-HealthScore }
            WindowsUpdate = Get-SafeDiagnosticValue 'Windows Update' { Get-WindowsUpdateDiagnostic }
            Drivers = Get-SafeDiagnosticValue 'Pilotes' { @(Get-DriverIssues) }
        }
        [IO.File]::WriteAllText((Join-Path $folder 'diagnostic.json'),($payload | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Select-Object Name,Location,User | Export-Csv (Join-Path $folder 'startup.csv') -NoTypeInformation -Encoding UTF8
        $recentLogs = @(Get-ChildItem -LiteralPath $script:LogRoot -Filter '*.log' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
        foreach ($log in $recentLogs) { Copy-Item -LiteralPath $log.FullName -Destination (Join-Path $folder $log.Name) }
        $notice = "Ce dossier peut contenir le modele du PC, des noms de peripheriques, des programmes au demarrage et des chemins locaux. Relisez son contenu avant de le partager."
        [IO.File]::WriteAllText((Join-Path $folder 'A_LIRE.txt'),$notice,[Text.UTF8Encoding]::new($false))
        Write-Log "Dossier de support : $folder" 'OK'
    } | Out-Null
}
