# Centre de diagnostic et de reparation des applications avec Windows Package Manager.

function Get-WinGetPath {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $command) {
        Write-Log 'WinGet est indisponible. Installer ou mettre a jour App Installer depuis Microsoft Store.' 'WARN'
        return $null
    }
    return $command.Source
}

function Read-WinGetPackageId {
    param([string]$Prompt)
    $id = ([string](Read-Host $Prompt)).Trim()
    if (-not $id) {
        Write-Log 'Identifiant de package vide : operation annulee.' 'WARN'
        return $null
    }
    return $id
}

function Show-WinGetStatus {
    $winget = Get-WinGetPath
    if (-not $winget) { return $false }
    return (Invoke-Action 'Etat de WinGet et de ses sources' -ReadOnly {
        Invoke-NativeCommand $winget @('--version') 'Version WinGet' | Out-Null
        Invoke-NativeCommand $winget @('source','list') 'Sources WinGet' | Out-Null
    })
}

function Show-WinGetUpdates {
    $winget = Get-WinGetPath
    if (-not $winget) { return $false }
    return (Invoke-Action 'Recherche des mises a jour disponibles' -ReadOnly {
        # 0x8A15002B signifie qu aucune mise a jour applicable n a ete trouvee.
        Invoke-NativeCommand $winget @('upgrade','--accept-source-agreements','--disable-interactivity') 'Applications a mettre a jour' -SuccessCodes @(0,-1978335189) | Out-Null
    })
}

function Update-WinGetPackage {
    $winget = Get-WinGetPath
    if (-not $winget) { return $false }
    $id = Read-WinGetPackageId 'Identifiant exact affiche par WinGet'
    if (-not $id -or -not (Confirm-Action "Mettre a jour uniquement le package $id")) { return $false }
    return (Invoke-Action "Mise a jour de $id" -AllowStandardUser {
        Invoke-NativeCommand $winget @('upgrade','--id',$id,'--exact','--accept-package-agreements','--accept-source-agreements','--disable-interactivity') "Mise a jour de $id" -SuccessCodes @(0,3010) | Out-Null
    })
}

function Repair-WinGetPackage {
    $winget = Get-WinGetPath
    if (-not $winget) { return $false }
    $id = Read-WinGetPackageId 'Identifiant exact du package a reparer'
    if (-not $id -or -not (Confirm-Action "Lancer la commande de reparation declaree par le package $id")) { return $false }
    return (Invoke-Action "Reparation de $id" -AllowStandardUser {
        $result = Invoke-NativeCommand $winget @('repair','--id',$id,'--exact','--accept-package-agreements','--accept-source-agreements','--disable-interactivity') "Reparation de $id" -SuccessCodes @(0,3010) -AllowFailure
        switch ($result.ExitCode) {
            -1978335111 { throw 'Cette application ne declare aucune commande de reparation dans WinGet.' }
            -1978335110 { throw 'La reparation WinGet ne s applique pas a cette installation.' }
            -1978335108 { throw 'La technologie d installation de cette application ne prend pas en charge la reparation.' }
            -1978335107 { throw 'Cette application est installee pour l utilisateur. Relancez SCRIPT_TOOL.bat avec -StandardUser puis recommencez.' }
        }
        if (-not $result.Success) { throw "La reparation WinGet a echoue avec le code $($result.ExitCode)." }
    })
}

function Export-WinGetInventory {
    $winget = Get-WinGetPath
    if (-not $winget) { return $false }
    $report = Join-Path $script:DataRoot "applications-$($script:Session).json"
    return (Invoke-Action 'Export de la liste des applications' -ReadOnly {
        Invoke-NativeCommand $winget @('export','--output',$report,'--include-versions','--accept-source-agreements','--disable-interactivity') 'Export des applications' | Out-Null
        Write-Log "Inventaire WinGet : $report" 'OK'
    })
}

function Start-ApplicationRepairCenter {
    do {
        Write-Host "`nCENTRE DE REPARATION DES APPLICATIONS" -ForegroundColor Cyan
        Write-Host '  [1] Verifier WinGet et ses sources'
        Write-Host '  [2] Afficher les mises a jour disponibles'
        Write-Host '  [3] Mettre a jour une application precise'
        Write-Host '  [4] Reparer une application precise'
        Write-Host '  [5] Exporter la liste des applications'
        Write-Host '  [0] Retour au menu principal'
        $choice = Read-Host 'Votre choix'
        switch ($choice) {
            '1' { Show-WinGetStatus | Out-Null }
            '2' { Show-WinGetUpdates | Out-Null }
            '3' { Update-WinGetPackage | Out-Null }
            '4' { Repair-WinGetPackage | Out-Null }
            '5' { Export-WinGetInventory | Out-Null }
            '0' { return }
            default { Write-Log 'Choix invalide dans le centre des applications.' 'WARN' }
        }
    } while ($true)
}
