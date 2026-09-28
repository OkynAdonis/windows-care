# Parcours de premiers secours : observer, expliquer, puis laisser choisir une correction.

function Start-SlowComputerFirstAid {
    Write-Host "`nPREMIERS SECOURS - PC LENT" -ForegroundColor Cyan
    Show-SystemResourceSnapshot
    Show-HeavyProcesses
    Show-StartupReport
    Write-Log 'Selon les constats : [35] Autoruns/Process Explorer, [30] application precise, [5] nettoyage si espace insuffisant. Controle : [31], puis reproduire la lenteur initiale.' 'WARN'
}

function Start-UnstableWindowsFirstAid {
    Write-Host "`nPREMIERS SECOURS - WINDOWS INSTABLE" -ForegroundColor Cyan
    $reboot = Get-PendingRebootState
    Write-Host "Redemarrage en attente : $($reboot.Pending)"
    if ($reboot.Reasons.Count) { Write-Host "Raisons : $($reboot.Reasons -join ', ')" }
    Show-RecentCriticalEvents
    Start-ProgressiveWindowsDiagnostic
    Write-Log 'Si une corruption est signalee : [6] reparation DISM/SFC. Controle : [33], puis reproduire le probleme apres le redemarrage demande. Une erreur critique seule ne prouve pas une corruption.' 'WARN'
}

function Start-NetworkFirstAid {
    Write-Host "`nPREMIERS SECOURS - CONNEXION" -ForegroundColor Cyan
    Show-NetworkDiagnostic
    Show-NetworkProxyState
    Test-DnsResponseTimes
    Write-Log 'Selon les constats : [34] approfondir, [7/8] DNS public si adapte au reseau, [9] reinitialisation si justifiee. Controle : [24], puis tester le service concerne. Respectez les DNS internes de l entreprise.' 'WARN'
}

function Start-SecurityFirstAid {
    Write-Host "`nPREMIERS SECOURS - SECURITE" -ForegroundColor Cyan
    Show-DefenderStatus | Out-Null
    Show-DefenderThreatHistory | Out-Null
    Write-Log 'Action : [32] signatures et analyse Defender. Controle : historique et etat dans [32]. Avec un antivirus tiers, utilisez aussi sa console ; un etat Defender seul ne conclut pas a une infection.' 'WARN'
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
