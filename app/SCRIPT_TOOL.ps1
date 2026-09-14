# SCRIPT - Outil Windows complet
# Propriete : TECH EXCHANGE
# Contact : +241 77 17 14 32 | techexchange50@gmail.com
# Ce fichier centralise les fonctions de diagnostic, maintenance et restauration.

[CmdletBinding()]
param([switch]$DryRun, [switch]$Restore, [switch]$ReportOnly, [switch]$RemoveMaintenanceTask, [string]$DataDirectory)

$ErrorActionPreference = 'Stop'
if (([int][bool]$Restore + [int][bool]$ReportOnly + [int][bool]$RemoveMaintenanceTask) -gt 1) { throw 'Choisir un seul mode : Restore, ReportOnly ou RemoveMaintenanceTask.' }
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DataRoot = if ($DataDirectory) { [IO.Path]::GetFullPath($DataDirectory) } else { Join-Path $script:Root 'data' }
$script:BackupRoot = Join-Path $script:DataRoot 'backups'
$script:LogRoot = Join-Path $script:DataRoot 'logs'
$script:Session = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$script:LogFile = Join-Path $script:LogRoot "session-$($script:Session).log"
$script:Simulation = [bool]$DryRun
$script:LastActionSucceeded = $true
try {
    New-Item -ItemType Directory -Force -Path $script:BackupRoot, $script:LogRoot -ErrorAction Stop | Out-Null
    [IO.File]::WriteAllText($script:LogFile,'')
} catch {
    if ($DataDirectory -or -not $env:LOCALAPPDATA) { throw "Dossier de donnees inaccessible : $script:DataRoot. $($_.Exception.Message)" }
    $script:DataRoot = Join-Path $env:LOCALAPPDATA 'WindowsCare\data'
    $script:BackupRoot = Join-Path $script:DataRoot 'backups'
    $script:LogRoot = Join-Path $script:DataRoot 'logs'
    $script:LogFile = Join-Path $script:LogRoot "session-$($script:Session).log"
    New-Item -ItemType Directory -Force -Path $script:BackupRoot, $script:LogRoot -ErrorAction Stop | Out-Null
    [IO.File]::WriteAllText($script:LogFile,'')
    Write-Host "Dossier du programme non inscriptible ; donnees dans $script:DataRoot" -ForegroundColor Yellow
}

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
        [switch]$AllowFailure,
        [int[]]$SuccessCodes = @(0)
    )

    $tempRoot = Join-Path $env:TEMP "windows-care-$($script:Session)"
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $stdoutPath = Join-Path $tempRoot ([guid]::NewGuid().ToString() + '.out')
    $stderrPath = Join-Path $tempRoot ([guid]::NewGuid().ToString() + '.err')
    $argumentString = ($Arguments | ForEach-Object {
        $argument = [string]$_
        if ($argument -eq '' -or $argument -match '[\s"]') {
            $argument = [regex]::Replace($argument, '(\\*)"', '$1$1\"')
            '"' + [regex]::Replace($argument, '(\\+)$', '$1$1') + '"'
        } else { $argument }
    }) -join ' '

    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $argumentString -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $stdout = [IO.File]::ReadAllText($stdoutPath)
        $stderr = [IO.File]::ReadAllText($stderrPath)
        $result = [pscustomobject]@{ Command = "$FilePath $argumentString"; ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr; Success = ($process.ExitCode -in $SuccessCodes) }
        if ($stdout.Trim()) { Write-Log "$Title | stdout : $($stdout.Trim())" }
        if ($stderr.Trim()) { Write-Log "$Title | stderr : $($stderr.Trim())" $(if ($result.Success) { 'WARN' } else { 'ERROR' }) }
        Write-Log "$Title | code de sortie : $($result.ExitCode)" $(if ($result.Success) { 'OK' } else { 'ERROR' })
        if ($result.ExitCode -eq 3010 -and $result.Success) { Write-Log 'Redemarrage Windows necessaire pour terminer cette operation.' 'WARN' }
        if (-not $result.Success -and -not $AllowFailure) { throw "La commande a echoue avec le code $($result.ExitCode)." }
        return $result
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

# Encadre une action pour gerer le mode simulation, les erreurs et le resultat.
function Invoke-Action {
    param([string]$Title, [scriptblock]$Action, [switch]$ReadOnly)
    Write-Log $Title
    $script:LastActionSucceeded = $false
    if ($script:Simulation -and -not $ReadOnly) { Write-Log 'Simulation : aucune modification appliquee.' 'WARN'; $script:LastActionSucceeded=$true; return $true }
    if (-not $ReadOnly -and -not (Test-Administrator)) { Write-Log 'Action refusee : relancer le BAT en administrateur. Les diagnostics restent disponibles.' 'ERROR'; return $false }
    try { & $Action | Out-Host; Write-Log "$Title : termine." 'OK'; $script:LastActionSucceeded=$true; return $true }
    catch { Write-Log "$Title : $($_.Exception.Message)" 'ERROR'; return $false }
}

# Demande une confirmation avant toute modification sensible.
function Confirm-Action {
    param([string]$Message)
    if ($script:Simulation) { return $true }
    return (Read-Host "$Message (O/N)") -match '^(O|o|Oui|oui)$'
}

# Affiche les sauvegardes disponibles et retourne celle choisie.
function Select-Backup {
    $items = @(Get-ChildItem -LiteralPath $script:BackupRoot -Directory | Sort-Object Name -Descending)
    if (-not $items) { Write-Log 'Aucune sauvegarde disponible.' 'WARN'; return $null }
    for ($i = 0; $i -lt $items.Count; $i++) { Write-Host "[$($i + 1)] $($items[$i].Name)" }
    $choice = Read-Host 'Choisir une sauvegarde'
    $index = 0
    if ([int]::TryParse($choice,[ref]$index) -and $index -ge 1 -and $index -le $items.Count) { return $items[$index - 1] }
    Write-Log 'Choix invalide.' 'WARN'; return $null
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
    if (Test-Path -LiteralPath (Join-Path $script:DataRoot 'temporary-power-plan.json')) { return }
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
    if ([string]$saved.Guid -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') { throw 'Plan temporaire invalide : fichier conserve pour verification.' }
    if (-not (Confirm-Action "Restaurer le plan precedent $($saved.Guid)")) { return }
    Invoke-Action 'Restauration du plan precedent' {
        New-StateBackup -Category Power | Out-Null
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

# Execute un parcours de diagnostic adapte au probleme choisi par l utilisateur.
function Start-RepairAssistant {
    Write-Host '[1] PC lent'; Write-Host '[2] Internet lent'; Write-Host '[3] Windows Update en panne'; Write-Host '[4] Disque presque plein'; Write-Host '[5] Confidentialite'
    $choice = Read-Host 'Quel probleme souhaitez-vous traiter'
    switch ($choice) {
        '1' { Show-HealthScore; Show-StartupReport; Clean-System }
        '2' { Show-Status; Reset-Network }
        '3' { if (Repair-Update) { Repair-Windows | Out-Null } }
        '4' { Show-HealthScore; Clean-System }
        '5' { Set-Privacy; Set-SearchPrivacy }
        default { Write-Log 'Choix invalide.' 'WARN' }
    }
}

# Applique des profils coherents et limites a un usage courant.
function Set-Profile {
    param([ValidateSet('Office','Gaming','Laptop','Privacy')][string]$Profile)
    switch ($Profile) {
        'Office' { Set-Performance -Mode Balanced }
        'Gaming' { Set-Performance -Mode Ultimate }
        'Laptop' { Set-Performance -Mode Balanced }
        'Privacy' { if (Set-Privacy) { Set-SearchPrivacy | Out-Null } }
    }
}

# Cree une tache hebdomadaire de diagnostic, sans appliquer de modification.
function Register-MaintenanceTask {
    param([string]$TaskName = 'TECH EXCHANGE - Rapport sante')
    if (-not (Confirm-Action 'Planifier un rapport de sante hebdomadaire')) { return }
    $scriptPath = Join-Path $script:Root 'SCRIPT_TOOL.ps1'
    Invoke-Action 'Planification de la maintenance hebdomadaire' {
        if (-not (Test-Path -LiteralPath $scriptPath)) { throw 'Script de rapport introuvable.' }
        $action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -DataDirectory `"$script:DataRoot`" -ReportOnly" -WorkingDirectory $script:Root
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '10:00'
        $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        Write-Log 'Rapport le dimanche a 10h, compte connecte. Replanifier si le dossier est deplace.'
    } | Out-Null
}

function Unregister-MaintenanceTask {
    if (-not (Confirm-Action 'Supprimer la maintenance hebdomadaire')) { return }
    Invoke-Action 'Suppression de la maintenance hebdomadaire' {
        Unregister-ScheduledTask -TaskName 'TECH EXCHANGE - Rapport sante' -Confirm:$false -ErrorAction Stop
    } | Out-Null
}

# Nettoie les fichiers temporaires et la corbeille.
function Clean-System {
    if (-not (Confirm-Action 'Supprimer les fichiers temporaires et vider la corbeille (fichiers non recuperables par Windows Care)')) { return }
    Invoke-Action 'Nettoyage des fichiers temporaires' {
        $skipped = 0
        foreach ($path in @($env:TEMP, "$env:WINDIR\Temp")) {
            $resolved = [IO.Path]::GetFullPath($path).TrimEnd('\')
            if ($resolved -eq [IO.Path]::GetPathRoot($resolved).TrimEnd('\') -or $resolved -eq $env:WINDIR -or $resolved -eq $env:USERPROFILE) { throw 'Dossier temporaire non sur.' }
            if (Test-Path -LiteralPath $resolved) {
                foreach ($item in Get-ChildItem -LiteralPath $resolved -Force -ErrorAction Stop) {
                    try { Remove-TemporaryEntry -Item $item -Root $resolved } catch { $skipped++; Write-Log $_.Exception.Message 'WARN' }
                }
            }
        }
        try { Clear-RecycleBin -Force -ErrorAction Stop } catch { $skipped++; Write-Log $_.Exception.Message 'WARN' }
        if ($skipped) { throw "Nettoyage partiel : $skipped element(s) ignore(s), verrouille(s) ou inaccessible(s)." }
    } | Out-Null
}

# Repare limage Windows puis verifie les fichiers systeme.
function Repair-Windows {
    if (-not (Confirm-Action 'Executer DISM puis SFC')) { return }
    $ok = Invoke-Action 'Reparation de limage Windows avec DISM' { Invoke-NativeCommand 'DISM.exe' @('/Online','/Cleanup-Image','/RestoreHealth') 'Reparation DISM' -SuccessCodes @(0,3010) | Out-Null }
    if (-not $ok) { return }
    Invoke-Action 'Verification des fichiers systeme avec SFC' { Invoke-NativeCommand 'sfc.exe' @('/scannow') 'Verification SFC' | Out-Null } | Out-Null
}

# Configure les serveurs DNS sur une interface reseau active choisie.
function Set-DnsServers {
    param([string[]]$Servers)
    $adapters = @(Get-NetAdapter | Where-Object Status -eq 'Up')
    if (-not $adapters) { Write-Log 'Aucune interface reseau active.' 'WARN'; return }
    for ($i = 0; $i -lt $adapters.Count; $i++) { Write-Host "[$($i + 1)] $($adapters[$i].Name)" }
    $choice = Read-Host 'Choisir une interface'
    $index = 0
    if (-not [int]::TryParse($choice,[ref]$index) -or $index -lt 1 -or $index -gt $adapters.Count) { Write-Log 'Choix invalide.' 'WARN'; return }
    $adapter = $adapters[$index - 1]
    if (-not (Confirm-Action "Configurer $($adapter.Name) avec $($Servers -join ', ')")) { return }
    Invoke-Action "Configuration DNS de $($adapter.Name)" {
        New-StateBackup -Category DNS -Adapter $adapter | Out-Null
        Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction Stop | Set-DnsClientServerAddress -ServerAddresses $Servers -ErrorAction Stop
    } | Out-Null
}

# Reinitialise Winsock, TCP/IP et le cache DNS.
function Reset-Network {
    if (-not (Confirm-Action 'Reinitialiser Winsock et TCP/IP (pas de restauration automatique de cette reinitialisation, redemarrage possible)')) { return }
    Invoke-Action 'Reinitialisation reseau' { Invoke-NativeCommand 'ipconfig.exe' @('/flushdns') 'Vidage cache DNS' | Out-Null; Invoke-NativeCommand 'netsh.exe' @('winsock','reset') 'Reinitialisation Winsock' | Out-Null; Invoke-NativeCommand 'netsh.exe' @('int','ip','reset') 'Reinitialisation TCP/IP' | Out-Null } | Out-Null
}

# Desactive certaines taches et regles de telemetrie Windows.
function Set-Privacy {
    if (-not (Confirm-Action 'Appliquer les reglages de confidentialite et telemetrie')) { return $false }
    return (Invoke-Action 'Configuration de la telemetrie Windows' {
        New-StateBackup -Category Privacy | Out-Null
        foreach ($task in Get-PrivacyTasks) { Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null }
        foreach ($service in Get-Service -ErrorAction Stop | Where-Object Name -in @('DiagTrack','diagsvc','WerSvc','wercplsupport')) { Set-Service -Name $service.Name -StartupType Manual -ErrorAction Stop }
        foreach ($item in Get-PrivacySettings) {
            if (-not (Test-Path -LiteralPath $item.Path)) { New-Item -Path $item.Path -Force -ErrorAction Stop | Out-Null }
            New-ItemProperty -LiteralPath $item.Path -Name $item.Name -PropertyType DWord -Value $item.Value -Force -ErrorAction Stop | Out-Null
        }
    })
}

# Parcourt explicitement les dossiers sans suivre les jonctions ou liens.
function Remove-TemporaryEntry {
    param([IO.FileSystemInfo]$Item, [string]$Root)
    $target = [IO.Path]::GetFullPath($Item.FullName)
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if (-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Element hors du dossier temporaire.' }
    foreach ($protected in @($script:Root,$script:DataRoot)) {
        $protectedPath = [IO.Path]::GetFullPath($protected).TrimEnd('\')
        if ($target -eq $protectedPath -or $protectedPath.StartsWith($target.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw "Dossier de l outil ignore : $target" }
    }
    if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Lien ignore : $target" }
    if ($Item.PSIsContainer) {
        foreach ($child in Get-ChildItem -LiteralPath $target -Force -ErrorAction Stop) { Remove-TemporaryEntry -Item $child -Root $Root }
    }
    Remove-Item -LiteralPath $target -Force -ErrorAction Stop
}
# Reduit les recherches web et les fonctions cloud de Windows Search.
function Set-SearchPrivacy {
    if (-not (Confirm-Action 'Desactiver la recherche web et les fonctions cloud de Search')) { return $false }
    return (Invoke-Action 'Configuration de Windows Search' {
        New-StateBackup -Category Search | Out-Null
        foreach ($item in Get-SearchSettings) {
            if (-not (Test-Path -LiteralPath $item.Path)) { New-Item -Path $item.Path -Force -ErrorAction Stop | Out-Null }
            New-ItemProperty -LiteralPath $item.Path -Name $item.Name -PropertyType DWord -Value $item.Value -Force -ErrorAction Stop | Out-Null
        }
    })
}
# Active un plan d alimentation standard ou performances optimales.
function Set-Performance {
    param([ValidateSet('Balanced','High','Ultimate')][string]$Mode)
    if (-not (Confirm-Action "Activer le plan de performance $Mode")) { return }
    Invoke-Action "Activation du plan $Mode" {
        $previousPlan = Get-ActivePowerPlanGuid
        if (-not $previousPlan) { throw 'Plan actif introuvable.' }
        New-StateBackup -Category Power | Out-Null
        $guid = switch ($Mode) {
            'Balanced' { '381b4222-f694-41f0-9685-ff5bb260df2e' }
            'High' { '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
            'Ultimate' { 'e9a42b02-d5df-448d-aa00-03f14749eb61' }
        }
        $plans = (Invoke-NativeCommand 'powercfg.exe' @('-list') 'Lecture plans alimentation').StdOut
        $ids = @([regex]::Matches($plans, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') | ForEach-Object Value)
        if ($guid -notin $ids) {
            # Windows choisit le GUID de la copie. Le recuperer dans la sortie evite
            # de reutiliser le GUID reserve du modele, refuse sur certaines editions.
            $created = Invoke-NativeCommand 'powercfg.exe' @('-duplicatescheme',$guid) "Creation plan $Mode"
            $createdGuid = [regex]::Match($created.StdOut + "`n" + $created.StdErr, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').Value
            if (-not $createdGuid) { throw 'Le plan a ete cree mais son identifiant est introuvable.' }
            $guid = $createdGuid
        }
        Save-TemporaryPowerPlan $previousPlan $Mode
        Invoke-NativeCommand 'powercfg.exe' @('-setactive',$guid) "Activation plan $Mode" | Out-Null
        if ((Get-ActivePowerPlanGuid) -ne $guid) { throw 'Le plan demande ne correspond pas au plan actif.' }
        $estimate = Get-PowerEnergyEstimate $Mode
        Write-Host "Cout energetique relatif : $($estimate.Cost) - $($estimate.Detail)" -ForegroundColor Yellow
        Write-Host 'Restauration disponible dans le menu avec le choix [22].' -ForegroundColor Cyan
    } | Out-Null
}
# Reinitialise les composants principaux de Windows Update.
function Repair-Update {
    if (-not (Confirm-Action 'Reinitialiser les caches Windows Update (anciens caches conserves sur disque, sans restauration automatique)')) { return $false }
    return (Invoke-Action 'Reparation de Windows Update' {
        $services = @(Get-Service -Name wuauserv,bits,cryptsvc -ErrorAction Stop | Select-Object Name,Status)
        $failures = [Collections.Generic.List[string]]::new()
        try {
            foreach ($service in $services) { Stop-Service -Name $service.Name -Force -ErrorAction Stop }
            $suffix = '.windows-care-' + [guid]::NewGuid().ToString('N')
            foreach ($path in @("$env:WINDIR\SoftwareDistribution", "$env:WINDIR\System32\catroot2")) {
                if (Test-Path -LiteralPath $path) {
                    $resolved = (Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath
                    $windowsRoot = (Resolve-Path -LiteralPath $env:WINDIR -ErrorAction Stop).ProviderPath.TrimEnd('\') + '\'
                    if (-not $resolved.StartsWith($windowsRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Cache hors du dossier Windows.' }
                    Rename-Item -LiteralPath $resolved -NewName ((Split-Path $resolved -Leaf) + $suffix) -ErrorAction Stop
                    Write-Log "Ancien cache conserve : $resolved$suffix"
                }
            }
        } catch { $failures.Add($_.Exception.Message) }
        finally {
            foreach ($service in $services | Where-Object Status -eq 'Running') {
                try { Start-Service -Name $service.Name -ErrorAction Stop } catch { $failures.Add($_.Exception.Message) }
            }
        }
        if ($failures.Count) { throw ($failures -join '; ') }
    })
}
# Fonctions de rapports courts pour les disques et les programmes au demarrage.
function Show-DiskHealth { Invoke-Action 'Lecture de letat des disques' -ReadOnly { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize } | Out-Null }
function Show-StartupReport { Invoke-Action 'Creation du rapport des programmes au demarrage' -ReadOnly { $report = Join-Path $script:DataRoot "startup-$($script:Session).txt"; Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Format-List | Out-File $report; Write-Log "Rapport : $report" 'OK' } | Out-Null }

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
    Write-Host '  [24] Diagnostic reseau detaille'
    Write-Host '  [25] Diagnostic Windows Update'
    Write-Host '  [26] Rechercher les pilotes en erreur'
    Write-Host '  [27] Creer un rapport batterie'
    Write-Host '  [28] Creer un point de restauration Windows'
    Write-Host '  [29] Creer un dossier de support partageable'
    Write-Host '  [ 0] Quitter'
}

. (Join-Path $script:Root 'State.ps1')
. (Join-Path $script:Root 'Health.ps1')
. (Join-Path $script:Root 'Support.ps1')
if ($ReportOnly) { try { New-HealthReport; exit 0 } catch { Write-Log $_.Exception.Message 'ERROR'; exit 1 } }
if ($RemoveMaintenanceTask -or $Restore) {
    try {
        if ($RemoveMaintenanceTask) { Unregister-MaintenanceTask } else { Restore-State }
        exit ([int](-not $script:LastActionSucceeded))
    } catch { Write-Log $_.Exception.Message 'ERROR'; exit 1 }
}
if (-not (Test-Administrator)) { Write-Log 'Session standard : diagnostics disponibles, modifications systeme reservees a un administrateur.' 'WARN' }
do {
    Show-Menu; $choice = Read-Host 'Votre choix'
    try { switch ($choice) {
        '1' { Show-Status; Pause-Tool }
        '2' { Show-HealthScore; Pause-Tool }
        '3' { New-HealthReport; Pause-Tool }
        '4' { Start-RepairAssistant; Pause-Tool }
        '5' { Clean-System; Pause-Tool }
        '6' { Repair-Windows; Pause-Tool }
        '7' { Set-DnsServers @('8.8.8.8','8.8.4.4'); Pause-Tool }
        '8' { Set-DnsServers @('1.1.1.1','1.0.0.1'); Pause-Tool }
        '9' { Reset-Network; Pause-Tool }
        '10' { Set-Privacy | Out-Null; Pause-Tool }
        '11' { Set-SearchPrivacy | Out-Null; Pause-Tool }
        '12' { Set-Profile Office; Pause-Tool }
        '13' { Set-Profile Gaming; Pause-Tool }
        '14' { Set-Profile Laptop; Pause-Tool }
        '15' { Set-Profile Privacy | Out-Null; Pause-Tool }
        '16' { Repair-Update | Out-Null; Pause-Tool }
        '17' { Show-DiskHealth; Pause-Tool }
        '18' { Show-StartupReport; Pause-Tool }
        '19' { Register-MaintenanceTask; Pause-Tool }
        '20' { Restore-State; Pause-Tool }
        '21' { $script:Simulation = -not $script:Simulation; Write-Log "Mode simulation : $script:Simulation" 'WARN'; Pause-Tool }
        '22' { Restore-TemporaryPowerPlan; Pause-Tool }
        '23' { Show-PowerEnergyCosts; Pause-Tool }
        '24' { Show-NetworkDiagnostic; Pause-Tool }
        '25' { Show-WindowsUpdateDiagnostic; Pause-Tool }
        '26' { Show-DriverIssues; Pause-Tool }
        '27' { New-BatteryDiagnostic; Pause-Tool }
        '28' { New-SystemRestorePoint; Pause-Tool }
        '29' { New-SupportBundle; Pause-Tool }
        '0' { return }
        default { Write-Log 'Choix invalide.' 'WARN'; Pause-Tool }
    }
    } catch { Write-Log $_.Exception.Message 'ERROR'; Pause-Tool }
} while ($true)
