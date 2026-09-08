# SCRIPT - Outil Windows complet
# Propriete : TECH EXCHANGE
# Contact : +241 77 17 14 32 | techexchange50@gmail.com
# Ce fichier centralise les fonctions de diagnostic, maintenance et restauration.

[CmdletBinding()]
param([switch]$DryRun, [switch]$Restore)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DataRoot = Join-Path $script:Root 'data'
$script:BackupRoot = Join-Path $script:DataRoot 'backups'
$script:LogRoot = Join-Path $script:DataRoot 'logs'
$script:Session = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:LogFile = Join-Path $script:LogRoot "session-$($script:Session).log"
$script:Simulation = [bool]$DryRun
New-Item -ItemType Directory -Force -Path $script:BackupRoot, $script:LogRoot | Out-Null

# Ecrit simultanement dans le journal de session et dans la console.
function Write-Log {
    param([string]$Message, [ValidateSet('INFO','OK','WARN','ERROR')] [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -LiteralPath $script:LogFile -Value $line
    Write-Host $line -ForegroundColor @{ INFO='Gray'; OK='Green'; WARN='Yellow'; ERROR='Red' }[$Level]
}

# Verifie que le processus possede les droits necessaires aux actions systeme.
function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Execute un programme Windows en separant sa sortie standard et ses erreurs.
# Une sortie non nulle devient une erreur exploitable par Invoke-Action.
function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$Title = $FilePath,
        [switch]$AllowFailure
    )

    $tempRoot = Join-Path $env:TEMP "windows-care-$($script:Session)"
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $stdoutPath = Join-Path $tempRoot ([guid]::NewGuid().ToString() + '.out')
    $stderrPath = Join-Path $tempRoot ([guid]::NewGuid().ToString() + '.err')
    $argumentString = ($Arguments | ForEach-Object {
        $argument = [string]$_
        if ($argument -match '[\s"]') { '"' + $argument.Replace('"', '\"') + '"' } else { $argument }
    }) -join ' '

    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $argumentString -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $stdout = if (Test-Path $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { '' }
        $stderr = if (Test-Path $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { '' }
        $result = [pscustomobject]@{ Command = "$FilePath $argumentString"; ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr; Success = ($process.ExitCode -eq 0) }
        if ($stdout.Trim()) { Write-Log "$Title | stdout : $($stdout.Trim())" }
        if ($stderr.Trim()) { Write-Log "$Title | stderr : $($stderr.Trim())" $(if ($result.Success) { 'WARN' } else { 'ERROR' }) }
        Write-Log "$Title | code de sortie : $($result.ExitCode)" $(if ($result.Success) { 'OK' } else { 'ERROR' })
        if (-not $result.Success -and -not $AllowFailure) { throw "La commande a echoue avec le code $($result.ExitCode)." }
        return $result
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

# Encadre une action pour gerer le mode simulation, les erreurs et le resultat.
function Invoke-Action {
    param([string]$Title, [scriptblock]$Action)
    Write-Log $Title
    if ($script:Simulation) { Write-Log 'Simulation : aucune modification appliquee.' 'WARN'; return $true }
    try { & $Action; Write-Log "$Title : termine." 'OK'; return $true }
    catch { Write-Log "$Title : $($_.Exception.Message)" 'ERROR'; return $false }
}

# Demande une confirmation avant toute modification sensible.
function Confirm-Action {
    param([string]$Message)
    if ($script:Simulation) { return $true }
    return (Read-Host "$Message (O/N)") -match '^(O|o|Oui|oui)$'
}

# Sauvegarde les reglages importants avant une modification.
function New-StateBackup {
    $path = Join-Path $script:BackupRoot $script:Session
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    try {
        Invoke-NativeCommand 'reg.exe' @('export','HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection',(Join-Path $path 'telemetry-hklm.reg'),'/y') 'Sauvegarde telemetrie' -AllowFailure | Out-Null
        Invoke-NativeCommand 'reg.exe' @('export','HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search',(Join-Path $path 'search-hkcu.reg'),'/y') 'Sauvegarde recherche' -AllowFailure | Out-Null
        Invoke-NativeCommand 'reg.exe' @('export','HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search',(Join-Path $path 'windows-search.reg'),'/y') 'Sauvegarde Windows Search' -AllowFailure | Out-Null
        Get-NetIPConfiguration | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $path 'network.json')
        (Invoke-NativeCommand 'powercfg.exe' @('-getactivescheme') 'Sauvegarde plan alimentation').StdOut | Set-Content (Join-Path $path 'power-plan.txt')
        Get-Service -Name DiagTrack,diagsvc,WerSvc,wercplsupport -ErrorAction SilentlyContinue | Select-Object Name,StartType,Status | ConvertTo-Json | Set-Content (Join-Path $path 'services.json')
        [pscustomobject]@{
            SchemaVersion = 1
            CreatedAt = (Get-Date).ToString('o')
            Product = 'Windows Care'
            Categories = @('Registry','Network','PowerPlan','Services')
            Files = @('telemetry-hklm.reg','search-hkcu.reg','windows-search.reg','network.json','power-plan.txt','services.json')
        } | ConvertTo-Json | Set-Content (Join-Path $path 'manifest.json')
        Write-Log "Sauvegarde creee : $path" 'OK'
    } catch { Write-Log "Sauvegarde incomplete : $($_.Exception.Message)" 'ERROR' }
    return $path
}

# Affiche les sauvegardes disponibles et retourne celle choisie.
function Select-Backup {
    $items = @(Get-ChildItem -LiteralPath $script:BackupRoot -Directory | Sort-Object Name -Descending)
    if (-not $items) { Write-Log 'Aucune sauvegarde disponible.' 'WARN'; return $null }
    for ($i = 0; $i -lt $items.Count; $i++) { Write-Host "[$($i + 1)] $($items[$i].Name)" }
    $choice = Read-Host 'Choisir une sauvegarde'
    if ($choice -as [int] -and $choice -ge 1 -and $choice -le $items.Count) { return $items[$choice - 1] }
    Write-Log 'Choix invalide.' 'WARN'; return $null
}

# Restaure les reglages exportes dans une sauvegarde precedente.
function Restore-State {
    $backup = Select-Backup
    if (-not $backup -or -not (Confirm-Action "Restaurer la sauvegarde $($backup.Name)")) { return }
    Invoke-Action "Restauration de $($backup.Name)" {
        foreach ($file in @('telemetry-hklm.reg','search-hkcu.reg','windows-search.reg')) {
            $path = Join-Path $backup.FullName $file
            if (Test-Path $path) { Invoke-NativeCommand 'reg.exe' @('import',$path) "Restauration registre $file" | Out-Null }
        }
        $power = Join-Path $backup.FullName 'power-plan.txt'
        if (Test-Path $power) {
            $guid = [regex]::Match((Get-Content $power -Raw), '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').Value
            if ($guid) { Invoke-NativeCommand 'powercfg.exe' @('-setactive',$guid) 'Restauration plan alimentation' | Out-Null }
        }
        $servicesPath = Join-Path $backup.FullName 'services.json'
        if (Test-Path $servicesPath) {
            foreach ($service in @(Get-Content $servicesPath -Raw | ConvertFrom-Json)) {
                Set-Service -Name $service.Name -StartupType $service.StartType -ErrorAction SilentlyContinue
            }
        }
        if (Test-Path (Join-Path $backup.FullName 'network.json')) {
            Write-Log 'Les parametres reseau sont conserves dans network.json; restauration automatique evitee pour proteger une interface differente.' 'WARN'
        }
    } | Out-Null
}

# Affiche un diagnostic rapide du systeme, des disques et du reseau.
function Show-Status {
    Write-Host "`nSYSTEME"
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,LastBootUpTime | Format-List
    Write-Host 'ESPACE DISQUE'
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID,@{N='LibreGo';E={[math]::Round($_.FreeSpace / 1GB,1)}},@{N='TotalGo';E={[math]::Round($_.Size / 1GB,1)}} | Format-Table
    Write-Host 'PLAN ACTIF'; Write-Host (Invoke-NativeCommand 'powercfg.exe' @('-getactivescheme') 'Lecture plan actif').StdOut
    Write-Host 'RESEAU'; Get-NetIPConfiguration | Where-Object IPv4Address | Select-Object InterfaceAlias,IPv4Address,DNSServer | Format-Table -AutoSize
}

# Retourne le GUID du plan d alimentation actuellement actif.
function Get-ActivePowerPlanGuid {
    $output = (Invoke-NativeCommand 'powercfg.exe' @('-getactivescheme') 'Lecture plan actif').StdOut
    return [regex]::Match($output, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').Value
}

# Donne un cout energetique relatif, car le prix reel depend du tarif local.
function Get-PowerEnergyEstimate {
    param([ValidateSet('Balanced','High','Ultimate')][string]$Mode)
    switch ($Mode) {
        'Balanced' { [pscustomobject]@{ Label = 'Equilibre'; Cost = 'Modere'; Detail = 'Bon compromis entre autonomie et performances.' } }
        'High' { [pscustomobject]@{ Label = 'Haute performance'; Cost = 'Eleve'; Detail = 'Consommation superieure pour une reactivite constante.' } }
        'Ultimate' { [pscustomobject]@{ Label = 'Performances optimales'; Cost = 'Tres eleve'; Detail = 'Priorite aux performances, autonomie reduite sur portable.' } }
    }
}

# Enregistre le plan precedent pour permettre une restauration apres la session.
function Save-TemporaryPowerPlan {
    param([string]$Guid, [string]$Profile)
    if (-not $Guid) { return }
    $estimate = Get-PowerEnergyEstimate $Profile
    [pscustomobject]@{ Guid = $Guid; Profile = $Profile; SavedAt = (Get-Date).ToString('o'); EnergyCost = $estimate.Cost } |
        ConvertTo-Json | Set-Content (Join-Path $script:DataRoot 'temporary-power-plan.json')
    Write-Log "Plan precedent sauvegarde pour restauration temporaire : $Guid" 'OK'
}

# Restaure le plan sauvegarde apres un profil temporaire.
function Restore-TemporaryPowerPlan {
    $path = Join-Path $script:DataRoot 'temporary-power-plan.json'
    if (-not (Test-Path $path)) { Write-Log 'Aucun plan temporaire a restaurer.' 'WARN'; return }
    $saved = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if (-not (Confirm-Action "Restaurer le plan precedent $($saved.Guid)")) { return }
    Invoke-Action 'Restauration du plan precedent' {
        Invoke-NativeCommand 'powercfg.exe' @('-setactive',$saved.Guid) 'Restauration plan temporaire' | Out-Null
        Remove-Item -LiteralPath $path -Force
    } | Out-Null
}

# Affiche l impact energetique relatif des profils disponibles.
function Show-PowerEnergyCosts {
    Write-Host "`nCOUT ENERGETIQUE RELATIF"
    foreach ($mode in @('Balanced','High','Ultimate')) {
        $estimate = Get-PowerEnergyEstimate $mode
        Write-Host ("{0,-24} {1,-10} {2}" -f $estimate.Label, $estimate.Cost, $estimate.Detail)
    }
    Write-Host 'Le cout reel depend du materiel, de la charge et du tarif electrique.'
}

# Calcule un score simple a partir de mesures disponibles sans modifier Windows.
function Get-HealthScore {
    $checks = [ordered]@{}
    $os = Get-CimInstance Win32_OperatingSystem
    $systemDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $freePercent = if ($systemDrive.Size) { [math]::Round(($systemDrive.FreeSpace / $systemDrive.Size) * 100) } else { 0 }
    $checks['Windows'] = if ($os.LastBootUpTime) { 100 } else { 50 }
    $checks['Stockage'] = if ($freePercent -ge 20) { 100 } elseif ($freePercent -ge 10) { 70 } else { 35 }
    $checks['Demarrage'] = if (@(Get-CimInstance Win32_StartupCommand).Count -le 8) { 100 } else { 65 }
    $checks['Defender'] = if ((Get-MpComputerStatus -ErrorAction SilentlyContinue).AntivirusEnabled) { 100 } else { 35 }
    $checks['Pare-feu'] = if (@(Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object Enabled -eq $true).Count -ge 1) { 100 } else { 30 }
    $checks['Reseau'] = if (@(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up').Count -ge 1) { 100 } else { 40 }
    $score = [math]::Round(($checks.Values | Measure-Object -Average).Average)
    [pscustomobject]@{ Score = $score; Checks = $checks; FreePercent = $freePercent }
}

# Affiche le score et les recommandations associees.
function Show-HealthScore {
    $health = Get-HealthScore
    Write-Host "`nSCORE DE SANTE : $($health.Score)/100" -ForegroundColor $(if ($health.Score -ge 80) { 'Green' } elseif ($health.Score -ge 60) { 'Yellow' } else { 'Red' })
    foreach ($item in $health.Checks.GetEnumerator()) { Write-Host ("{0,-16} {1,3}/100" -f $item.Key, $item.Value) }
    if ($health.FreePercent -lt 10) { Write-Log 'Recommandation : liberer de lespace disque.' 'WARN' }
    if ($health.Checks['Demarrage'] -lt 80) { Write-Log 'Recommandation : examiner les programmes au demarrage.' 'WARN' }
    if ($health.Checks['Defender'] -lt 80) { Write-Log 'Recommandation : verifier Microsoft Defender.' 'WARN' }
}

# Genere un rapport HTML partageable avec les mesures et les recommandations.
function New-HealthReport {
    $health = Get-HealthScore
    $rows = ($health.Checks.GetEnumerator() | ForEach-Object { "<tr><td>$($_.Key)</td><td>$($_.Value)/100</td></tr>" }) -join "`n"
    $report = Join-Path $script:DataRoot "rapport-$($script:Session).html"
    $html = @"
<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Rapport TECH EXCHANGE</title>
<style>body{font-family:Segoe UI,Arial;background:#eef2f5;color:#17212b;max-width:850px;margin:40px auto;padding:24px}main{background:white;padding:28px;border-radius:10px;box-shadow:0 4px 18px #0001}h1{color:#0b6670}table{width:100%;border-collapse:collapse}td{padding:10px;border-bottom:1px solid #dde4e8}footer{margin-top:28px;color:#64727c}</style></head>
<body><main><h1>Rapport de sante Windows</h1><p><b>TECH EXCHANGE</b> | $([datetime]::Now.ToString('dd/MM/yyyy HH:mm'))</p><h2>Score : $($health.Score)/100</h2><table><tr><th align="left">Categorie</th><th align="left">Resultat</th></tr>$rows</table><footer>Contact : +241 77 17 14 32 | techexchange50@gmail.com</footer></main></body></html>
"@
    Set-Content -LiteralPath $report -Value $html -Encoding UTF8
    Write-Log "Rapport HTML cree : $report" 'OK'
}

# Execute un parcours de diagnostic adapte au probleme choisi par l utilisateur.
function Start-RepairAssistant {
    Write-Host '[1] PC lent'; Write-Host '[2] Internet lent'; Write-Host '[3] Windows Update en panne'; Write-Host '[4] Disque presque plein'; Write-Host '[5] Confidentialite'
    $choice = Read-Host 'Quel probleme souhaitez-vous traiter'
    switch ($choice) {
        '1' { Show-HealthScore; Show-StartupReport; Clean-System }
        '2' { Show-Status; Reset-Network }
        '3' { Repair-Update; Repair-Windows }
        '4' { Show-HealthScore; Clean-System }
        '5' { Set-Privacy; Set-SearchPrivacy }
        default { Write-Log 'Choix invalide.' 'WARN' }
    }
}

# Applique des profils coherents et limites a un usage courant.
function Set-Profile {
    param([ValidateSet('Office','Gaming','Laptop','Privacy')][string]$Profile)
    switch ($Profile) {
        'Office' { Set-Performance -Mode High; Write-Log 'Profil Bureautique : performance stable.' 'OK' }
        'Gaming' { Set-Performance -Mode Ultimate; Write-Log 'Profil Gaming : plan de performance active.' 'OK' }
        'Laptop' { Set-Performance -Mode Balanced }
        'Privacy' { Set-Privacy; Set-SearchPrivacy }
    }
}

# Cree une tache hebdomadaire de diagnostic, sans appliquer de modification.
function Register-MaintenanceTask {
    if (-not (Confirm-Action 'Planifier un rapport de sante hebdomadaire')) { return }
    $scriptPath = Join-Path $script:Root 'SCRIPT_TOOL.ps1'
    Invoke-Action 'Planification de la maintenance hebdomadaire' {
        $action = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -DryRun"
        Invoke-NativeCommand 'schtasks.exe' @('/Create','/TN','TECH EXCHANGE - Rapport sante','/TR',$action,'/SC','WEEKLY','/D','SUN','/ST','10:00','/F') 'Planification rapport sante' | Out-Null
    } | Out-Null
}

# Nettoie les fichiers temporaires et la corbeille.
function Clean-System {
    if (-not (Confirm-Action 'Nettoyer les fichiers temporaires et la corbeille')) { return }
    New-StateBackup | Out-Null
    Invoke-Action 'Nettoyage des fichiers temporaires' {
        foreach ($path in @($env:TEMP, "$env:WINDIR\Temp", "$env:WINDIR\Prefetch")) {
            if (Test-Path $path) { Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    } | Out-Null
}

# Repare limage Windows puis verifie les fichiers systeme.
function Repair-Windows {
    if (-not (Confirm-Action 'Executer DISM puis SFC')) { return }
    New-StateBackup | Out-Null
    Invoke-Action 'Reparation de limage Windows avec DISM' { Invoke-NativeCommand 'DISM.exe' @('/Online','/Cleanup-Image','/RestoreHealth') 'Reparation DISM' | Out-Null } | Out-Null
    Invoke-Action 'Verification des fichiers systeme avec SFC' { Invoke-NativeCommand 'sfc.exe' @('/scannow') 'Verification SFC' | Out-Null } | Out-Null
}

# Configure les serveurs DNS sur une interface reseau active choisie.
function Set-DnsServers {
    param([string[]]$Servers)
    $adapters = @(Get-NetAdapter | Where-Object Status -eq 'Up')
    if (-not $adapters) { Write-Log 'Aucune interface reseau active.' 'WARN'; return }
    for ($i = 0; $i -lt $adapters.Count; $i++) { Write-Host "[$($i + 1)] $($adapters[$i].Name)" }
    $choice = Read-Host 'Choisir une interface'
    if (-not ($choice -as [int]) -or $choice -lt 1 -or $choice -gt $adapters.Count) { Write-Log 'Choix invalide.' 'WARN'; return }
    $adapter = $adapters[$choice - 1]
    if (-not (Confirm-Action "Configurer $($adapter.Name) avec $($Servers -join ', ')")) { return }
    New-StateBackup | Out-Null
    Invoke-Action "Configuration DNS de $($adapter.Name)" { Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $Servers } | Out-Null
}

# Reinitialise Winsock, TCP/IP et le cache DNS.
function Reset-Network {
    if (-not (Confirm-Action 'Reinitialiser le reseau et vider le cache DNS')) { return }
    New-StateBackup | Out-Null
    Invoke-Action 'Reinitialisation reseau' { Invoke-NativeCommand 'ipconfig.exe' @('/flushdns') 'Vidage cache DNS' | Out-Null; Invoke-NativeCommand 'netsh.exe' @('winsock','reset') 'Reinitialisation Winsock' | Out-Null; Invoke-NativeCommand 'netsh.exe' @('int','ip','reset') 'Reinitialisation TCP/IP' | Out-Null } | Out-Null
}

# Desactive certaines taches et regles de telemetrie Windows.
function Set-Privacy {
    if (-not (Confirm-Action 'Appliquer les reglages de confidentialite et telemetrie')) { return }
    New-StateBackup | Out-Null
    Invoke-Action 'Configuration de la telemetrie Windows' {
        foreach ($task in @('\Microsoft\Windows\Customer Experience Improvement Program\Consolidator','\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask','\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip','\Microsoft\Windows\Autochk\Proxy','\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector','\Microsoft\Windows\Feedback\Siuf\DmClient','\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload','\Microsoft\Windows\Windows Error Reporting\QueueReporting')) { Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null }
        foreach ($service in @('DiagTrack','diagsvc','WerSvc','wercplsupport')) { Set-Service -Name $service -StartupType Manual -ErrorAction SilentlyContinue }
        foreach ($item in @(@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection','AllowTelemetry',0),@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection','DisableOneSettingsDownloads',1),@('HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows','CEIPEnable',0),@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection','AllowTelemetry',0),@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting','Disabled',1),@('HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting','Disabled',1))) { New-Item -Path $item[0] -Force | Out-Null; New-ItemProperty -Path $item[0] -Name $item[1] -PropertyType DWord -Value $item[2] -Force | Out-Null }
    } | Out-Null
}

# Reduit les recherches web et les fonctions cloud de Windows Search.
function Set-SearchPrivacy {
    if (-not (Confirm-Action 'Desactiver la recherche web et les fonctions cloud de Search')) { return }
    New-StateBackup | Out-Null
    Invoke-Action 'Configuration de Windows Search' {
        $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; New-Item -Path $path -Force | Out-Null
        foreach ($item in @('ConnectedSearchUseWeb','DisableWebSearch','AllowCloudSearch','AllowCortana')) { New-ItemProperty -Path $path -Name $item -PropertyType DWord -Value 0 -Force | Out-Null }
        New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name BingSearchEnabled -PropertyType DWord -Value 0 -Force | Out-Null
    } | Out-Null
}

# Active un plan d alimentation standard ou performances optimales.
function Set-Performance {
    param([ValidateSet('Balanced','High','Ultimate')][string]$Mode)
    if (-not (Confirm-Action "Activer le plan de performance $Mode")) { return }
    $previousPlan = $null
    try { $previousPlan = Get-ActivePowerPlanGuid }
    catch { Write-Log "Impossible de lire le plan actif avant changement : $($_.Exception.Message)" 'WARN' }
    New-StateBackup | Out-Null
    $guid = switch ($Mode) {
        'Balanced' { 'SCHEME_BALANCED' }
        'High' { '8c5e7fda-e8df-4a96-9a96-a6e23a8c635c' }
        'Ultimate' { 'e9a42b02-d5df-448d-aa00-03f14749eb61' }
    }
    Invoke-Action "Activation du plan $Mode" {
        if ($Mode -ne 'Balanced') {
            Invoke-NativeCommand 'powercfg.exe' @('-duplicatescheme',$guid) "Creation plan $Mode" -AllowFailure | Out-Null
            $plans = (Invoke-NativeCommand 'powercfg.exe' @('-list') 'Lecture plans alimentation').StdOut
            $line = $plans | Select-String -Pattern $Mode | Select-Object -First 1
            $found = [regex]::Match($line.Line, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').Value
            $guid = if ($found) { $found } else { $guid }
        }
        Invoke-NativeCommand 'powercfg.exe' @('-setactive',$guid) "Activation plan $Mode" | Out-Null
        Save-TemporaryPowerPlan $previousPlan $Mode
        $estimate = Get-PowerEnergyEstimate $Mode
        Write-Host "Cout energetique relatif : $($estimate.Cost) - $($estimate.Detail)" -ForegroundColor Yellow
        Write-Host 'Restauration disponible dans le menu avec le choix [22].' -ForegroundColor Cyan
    } | Out-Null
}

# Reinitialise les composants principaux de Windows Update.
function Repair-Update {
    if (-not (Confirm-Action 'Reinitialiser le cache Windows Update')) { return }
    New-StateBackup | Out-Null
    Invoke-Action 'Reparation de Windows Update' { Stop-Service wuauserv,bits,cryptsvc -Force -ErrorAction SilentlyContinue; Rename-Item "$env:WINDIR\SoftwareDistribution" 'SoftwareDistribution.old' -ErrorAction SilentlyContinue; Rename-Item "$env:WINDIR\System32\catroot2" 'catroot2.old' -ErrorAction SilentlyContinue; Start-Service cryptsvc,bits,wuauserv -ErrorAction SilentlyContinue } | Out-Null
}

# Fonctions de rapports courts pour les disques et les programmes au demarrage.
function Show-DiskHealth { Invoke-Action 'Lecture de letat des disques' { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize } | Out-Null }
function Show-StartupReport { Invoke-Action 'Creation du rapport des programmes au demarrage' { $report = Join-Path $script:DataRoot "startup-$($script:Session).txt"; Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Format-List | Out-File $report; Write-Log "Rapport : $report" 'OK' } | Out-Null }

function Pause-Tool { Read-Host 'Appuyer sur Entree pour continuer' | Out-Null }

# Affiche une seule colonne de choix pour rester lisible dans toutes les consoles.
function Show-Menu {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '              SCRIPT - OUTIL WINDOWS COMPLET' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'Proprietaire : TECH EXCHANGE' -ForegroundColor White
    Write-Host 'Contact      : +241 77 17 14 32 | techexchange50@gmail.com' -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host "Journal : $script:LogFile"
    Write-Host "Mode simulation : $script:Simulation`n" -ForegroundColor Yellow
    Write-Host 'CHOISIR UNE ACTION' -ForegroundColor Cyan
    Write-Host '  [ 1] Etat systeme'
    Write-Host '  [ 2] Score de sante du PC'
    Write-Host '  [ 3] Rapport HTML de sante'
    Write-Host '  [ 4] Assistant de reparation'
    Write-Host '  [ 5] Nettoyage fichiers temporaires et corbeille'
    Write-Host '  [ 6] Reparation Windows (DISM puis SFC)'
    Write-Host '  [ 7] Configurer DNS Google'
    Write-Host '  [ 8] Configurer DNS Cloudflare'
    Write-Host '  [ 9] Reinitialiser le reseau'
    Write-Host '  [10] Confidentialite et telemetrie'
    Write-Host '  [11] Confidentialite Windows Search'
    Write-Host '  [12] Profil Bureautique'
    Write-Host '  [13] Profil Gaming'
    Write-Host '  [14] Profil Portable'
    Write-Host '  [15] Profil Confidentialite'
    Write-Host '  [16] Reparer Windows Update'
    Write-Host '  [17] Etat des disques'
    Write-Host '  [18] Rapport des programmes au demarrage'
    Write-Host '  [19] Planifier maintenance hebdomadaire'
    Write-Host '  [20] Restaurer une sauvegarde'
    Write-Host '  [21] Activer/desactiver le mode simulation'
    Write-Host '  [22] Restaurer le plan apres session'
    Write-Host '  [23] Voir les couts energetiques relatifs'
    Write-Host '  [ 0] Quitter'
}

if (-not (Test-Administrator)) { Write-Log 'L outil doit etre lance en tant qu administrateur.' 'ERROR'; exit 1 }
if ($Restore) { Restore-State; exit }
do {
    Show-Menu; $choice = Read-Host 'Votre choix'
    switch ($choice) {
        '1' { Show-Status; Pause-Tool }
        '2' { Show-HealthScore; Pause-Tool }
        '3' { New-HealthReport; Pause-Tool }
        '4' { Start-RepairAssistant; Pause-Tool }
        '5' { Clean-System; Pause-Tool }
        '6' { Repair-Windows; Pause-Tool }
        '7' { Set-DnsServers @('8.8.8.8','8.8.4.4'); Pause-Tool }
        '8' { Set-DnsServers @('1.1.1.1','1.0.0.1'); Pause-Tool }
        '9' { Reset-Network; Pause-Tool }
        '10' { Set-Privacy; Pause-Tool }
        '11' { Set-SearchPrivacy; Pause-Tool }
        '12' { Set-Profile Office; Pause-Tool }
        '13' { Set-Profile Gaming; Pause-Tool }
        '14' { Set-Profile Laptop; Pause-Tool }
        '15' { Set-Profile Privacy; Pause-Tool }
        '16' { Repair-Update; Pause-Tool }
        '17' { Show-DiskHealth; Pause-Tool }
        '18' { Show-StartupReport; Pause-Tool }
        '19' { Register-MaintenanceTask; Pause-Tool }
        '20' { Restore-State; Pause-Tool }
        '21' { $script:Simulation = -not $script:Simulation; Write-Log "Mode simulation : $script:Simulation" 'WARN'; Pause-Tool }
        '22' { Restore-TemporaryPowerPlan; Pause-Tool }
        '23' { Show-PowerEnergyCosts; Pause-Tool }
        '0' { break }
        default { Write-Log 'Choix invalide.' 'WARN'; Pause-Tool }
    }
} while ($true)