# Controle Windows par etapes : diagnostic avant toute reparation.

function Test-ComponentStoreHealth {
    Invoke-Action 'Diagnostic rapide du magasin de composants' -ReadOnly {
        Invoke-NativeCommand 'DISM.exe' @('/Online','/Cleanup-Image','/CheckHealth') 'DISM CheckHealth' | Out-Null
    } | Out-Null
}

function Test-ComponentStoreDeepHealth {
    Invoke-Action 'Analyse approfondie du magasin de composants' -ReadOnly {
        Invoke-NativeCommand 'DISM.exe' @('/Online','/Cleanup-Image','/ScanHealth') 'DISM ScanHealth' | Out-Null
    } | Out-Null
}

function Test-SystemFilesIntegrity {
    Invoke-Action 'Verification des fichiers systeme sans reparation' -ReadOnly {
        Invoke-NativeCommand 'sfc.exe' @('/verifyonly') 'SFC VerifyOnly' | Out-Null
    } | Out-Null
}

function Test-SystemDriveOnline {
    $drive = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
    Invoke-Action 'Analyse en ligne du disque systeme' -ReadOnly {
        Invoke-NativeCommand 'chkdsk.exe' @($drive,'/scan') "CHKDSK $drive" | Out-Null
    } | Out-Null
}

function Start-ProgressiveWindowsDiagnostic {
    Write-Host "`nETAPE 1/4 - Etat rapide des composants" -ForegroundColor Cyan
    Test-ComponentStoreHealth
    Write-Host "`nETAPE 2/4 - Analyse approfondie des composants" -ForegroundColor Cyan
    Test-ComponentStoreDeepHealth
    Write-Host "`nETAPE 3/4 - Verification des fichiers systeme" -ForegroundColor Cyan
    Test-SystemFilesIntegrity
    Write-Host "`nETAPE 4/4 - Analyse en ligne du disque systeme" -ForegroundColor Cyan
    Test-SystemDriveOnline
    Write-Log 'Diagnostic progressif termine. Consultez les codes et messages ci-dessus avant de choisir une reparation.' 'OK'
}

function Start-ProgressiveDiagnosticCenter {
    do {
        Write-Host "`nDIAGNOSTIC WINDOWS PROGRESSIF" -ForegroundColor Cyan
        Write-Host '  [1] Controle rapide DISM CheckHealth'
        Write-Host '  [2] Analyse DISM ScanHealth'
        Write-Host '  [3] Verification SFC sans reparation'
        Write-Host '  [4] Analyse CHKDSK en ligne'
        Write-Host '  [5] Executer les quatre diagnostics'
        Write-Host '  [6] Proposer ensuite la reparation DISM/SFC'
        Write-Host '  [0] Retour au menu principal'
        switch (Read-Host 'Votre choix') {
            '1' { Test-ComponentStoreHealth }
            '2' { Test-ComponentStoreDeepHealth }
            '3' { Test-SystemFilesIntegrity }
            '4' { Test-SystemDriveOnline }
            '5' { Start-ProgressiveWindowsDiagnostic }
            '6' { Repair-Windows }
            '0' { return }
            default { Write-Log 'Choix invalide dans le diagnostic progressif.' 'WARN' }
        }
    } while ($true)
}
