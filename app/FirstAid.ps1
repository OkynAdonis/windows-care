# Parcours de premiers secours : observer, expliquer, puis laisser choisir une correction.

function Start-SlowComputerFirstAid {
    Write-Host "`nPREMIERS SECOURS - PC LENT" -ForegroundColor Cyan
    Show-SystemResourceSnapshot
    Show-HeavyProcesses
    Show-StartupReport
    Write-Log 'Examinez les processus et le rapport de demarrage avant de nettoyer ou desinstaller une application.' 'WARN'
}

function Start-UnstableWindowsFirstAid {
    Write-Host "`nPREMIERS SECOURS - WINDOWS INSTABLE" -ForegroundColor Cyan
    $reboot = Get-PendingRebootState
    Write-Host "Redemarrage en attente : $($reboot.Pending)"
    if ($reboot.Reasons.Count) { Write-Host "Raisons : $($reboot.Reasons -join ', ')" }
    Show-RecentCriticalEvents
    Start-ProgressiveWindowsDiagnostic
    Write-Log 'Si les diagnostics signalent une corruption, utilisez la reparation DISM/SFC depuis le diagnostic progressif.' 'WARN'
}

function Start-NetworkFirstAid {
    Write-Host "`nPREMIERS SECOURS - CONNEXION" -ForegroundColor Cyan
    Show-NetworkDiagnostic
    Show-NetworkProxyState
    Test-DnsResponseTimes
    Write-Log 'Ne reinitialisez le reseau qu apres avoir identifie une anomalie de configuration.' 'WARN'
}

function Start-SecurityFirstAid {
    Write-Host "`nPREMIERS SECOURS - SECURITE" -ForegroundColor Cyan
    Show-DefenderStatus | Out-Null
    Show-DefenderThreatHistory | Out-Null
    Write-Log 'Utilisez ensuite le centre Microsoft Defender pour mettre a jour les signatures ou lancer une analyse.' 'WARN'
}

function Start-FirstAidCenter {
    do {
        Write-Host "`nPREMIERS SECOURS WINDOWS CARE" -ForegroundColor Cyan
        Write-Host '  [1] Mon PC est lent'
        Write-Host '  [2] Windows est instable ou affiche des erreurs'
        Write-Host '  [3] Internet ou le reseau fonctionne mal'
        Write-Host '  [4] Je suspecte un probleme de securite'
        Write-Host '  [5] Creer un dossier de support complet'
        Write-Host '  [0] Retour au menu principal'
        switch (Read-Host 'Votre symptome') {
            '1' { Start-SlowComputerFirstAid }
            '2' { Start-UnstableWindowsFirstAid }
            '3' { Start-NetworkFirstAid }
            '4' { Start-SecurityFirstAid }
            '5' { New-SupportBundle }
            '0' { return }
            default { Write-Log 'Choix invalide dans Premiers secours.' 'WARN' }
        }
    } while ($true)
}
