# Etat, mise a jour et analyses Microsoft Defender avec confirmations explicites.

function Test-DefenderAvailable {
    if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        Write-Log 'Les commandes Microsoft Defender sont indisponibles sur cette machine.' 'WARN'
        return $false
    }
    return $true
}

function Show-DefenderStatus {
    if (-not (Test-DefenderAvailable)) { return $false }
    return (Invoke-Action 'Etat de Microsoft Defender' -ReadOnly {
        Get-MpComputerStatus -ErrorAction Stop | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,IoavProtectionEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,QuickScanAge,FullScanAge,ComputerState | Format-List
    })
}

function Show-DefenderThreatHistory {
    if (-not (Test-DefenderAvailable)) { return $false }
    return (Invoke-Action 'Historique des menaces Microsoft Defender' -ReadOnly {
        $threats = @(Get-MpThreatDetection -ErrorAction Stop | Sort-Object InitialDetectionTime -Descending | Select-Object -First 30 InitialDetectionTime,ThreatID,ActionSuccess,Resources)
        if ($threats.Count) { $threats | Format-List }
        else { Write-Log 'Aucune detection presente dans l historique accessible.' 'OK' }
    })
}

function Update-DefenderSignatures {
    if (-not (Test-DefenderAvailable)) { return $false }
    if (-not (Confirm-Action 'Telecharger les dernieres signatures Microsoft Defender')) { return $false }
    return (Invoke-Action 'Mise a jour des signatures Microsoft Defender' {
        Write-Progress -Id 6 -Activity 'Microsoft Defender' -Status 'Mise a jour des signatures en cours' -PercentComplete -1
        Update-MpSignature -ErrorAction Stop
        Write-Progress -Id 6 -Activity 'Microsoft Defender' -Completed
    })
}

function Start-DefenderScan {
    param([ValidateSet('QuickScan','FullScan')][string]$ScanType)
    if (-not (Test-DefenderAvailable)) { return $false }
    $label = if ($ScanType -eq 'QuickScan') { 'analyse rapide' } else { 'analyse complete, potentiellement longue' }
    if (-not (Confirm-Action "Lancer une $label avec Microsoft Defender")) { return $false }
    return (Invoke-Action "Microsoft Defender - $label" {
        Write-Progress -Id 6 -Activity 'Microsoft Defender' -Status "$label en cours" -PercentComplete -1
        Start-MpScan -ScanType $ScanType -ErrorAction Stop
        Write-Progress -Id 6 -Activity 'Microsoft Defender' -Completed
    })
}

function Start-DefenderOfflineScan {
    if (-not (Test-DefenderAvailable)) { return $false }
    if (-not (Get-Command Start-MpWDOScan -ErrorAction SilentlyContinue)) {
        Write-Log 'L analyse hors ligne Microsoft Defender est indisponible sur cette machine.' 'WARN'
        return $false
    }
    if (-not (Confirm-Action 'ENREGISTRER VOTRE TRAVAIL puis redemarrer maintenant pour l analyse Microsoft Defender hors ligne')) { return $false }
    return (Invoke-Action 'Demarrage de Microsoft Defender hors ligne' {
        Write-Log 'Windows va redemarrer pour effectuer l analyse hors ligne.' 'WARN'
        Write-Progress -Id 6 -Activity 'Microsoft Defender hors ligne' -Status 'Preparation du redemarrage' -PercentComplete -1
        Start-MpWDOScan -ErrorAction Stop
    })
}

function Start-DefenderCenter {
    do {
        Write-Host "`nCENTRE MICROSOFT DEFENDER" -ForegroundColor Cyan
        Write-Host '  [1] Afficher l etat de la protection'
        Write-Host '  [2] Afficher l historique des menaces'
        Write-Host '  [3] Mettre a jour les signatures'
        Write-Host '  [4] Lancer une analyse rapide'
        Write-Host '  [5] Lancer une analyse complete'
        Write-Host '  [6] Lancer une analyse hors ligne (redemarrage)'
        Write-Host '  [0] Retour au menu principal'
        switch (Read-Host 'Votre choix') {
            '1' { Show-DefenderStatus | Out-Null }
            '2' { Show-DefenderThreatHistory | Out-Null }
            '3' { Update-DefenderSignatures | Out-Null }
            '4' { Start-DefenderScan QuickScan | Out-Null }
            '5' { Start-DefenderScan FullScan | Out-Null }
            '6' { Start-DefenderOfflineScan | Out-Null }
            '0' { return }
            default { Write-Log 'Choix invalide dans le centre Microsoft Defender.' 'WARN' }
        }
    } while ($true)
}
