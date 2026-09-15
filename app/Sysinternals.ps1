# Installation et lancement controles des utilitaires Microsoft Sysinternals.

function Get-SysinternalsCatalog {
    @(
        [pscustomobject]@{Number='1';Name='Autoruns';Command='Autoruns64.exe';Package='Microsoft.Sysinternals';Purpose='Programmes, services et extensions lances automatiquement'}
        [pscustomobject]@{Number='2';Name='Process Explorer';Command='procexp64.exe';Package='Microsoft.Sysinternals';Purpose='Processus, DLL et utilisation des ressources'}
        [pscustomobject]@{Number='3';Name='TCPView';Command='Tcpview.exe';Package='Microsoft.Sysinternals';Purpose='Connexions TCP et UDP ouvertes'}
        [pscustomobject]@{Number='4';Name='RAMMap';Command='RAMMap.exe';Package='Microsoft.Sysinternals';Purpose='Repartition detaillee de la memoire'}
        [pscustomobject]@{Number='5';Name='Sigcheck';Command='sigcheck64.exe';Package='Microsoft.Sysinternals';Purpose='Signatures numeriques et versions de fichiers'}
    )
}

function Show-SysinternalsStatus {
    Invoke-Action 'Etat des outils Microsoft Sysinternals' -ReadOnly {
        Get-SysinternalsCatalog | ForEach-Object {
            $command = Get-Command $_.Command -ErrorAction SilentlyContinue
            [pscustomobject]@{Tool=$_.Name;Available=[bool]$command;Purpose=$_.Purpose;Package=$_.Package}
        } | Format-Table -AutoSize
    } | Out-Null
}

function Select-SysinternalsTool {
    $catalog = @(Get-SysinternalsCatalog)
    foreach ($item in $catalog) { Write-Host "  [$($item.Number)] $($item.Name) - $($item.Purpose)" }
    $choice = Read-Host 'Choisir un outil'
    return @($catalog | Where-Object Number -eq $choice | Select-Object -First 1)[0]
}

function Install-SysinternalsTool {
    $winget = Get-WinGetPath
    if (-not $winget) { return $false }
    $tool = Select-SysinternalsTool
    if (-not $tool) { Write-Log 'Outil Sysinternals invalide.' 'WARN'; return $false }
    if (-not (Confirm-Action "Installer la suite Microsoft Sysinternals pour utiliser $($tool.Name), avec le package exact $($tool.Package)")) { return $false }
    return (Invoke-Action 'Installation de Microsoft Sysinternals' -AllowStandardUser {
        Invoke-NativeCommand $winget @('install','--id',$tool.Package,'--exact','--source','winget','--accept-package-agreements','--accept-source-agreements','--disable-interactivity') 'Installation de Microsoft Sysinternals' -SuccessCodes @(0,3010) | Out-Null
    })
}

function Start-SysinternalsTool {
    $tool = Select-SysinternalsTool
    if (-not $tool) { Write-Log 'Outil Sysinternals invalide.' 'WARN'; return $false }
    $command = Get-Command $tool.Command -ErrorAction SilentlyContinue
    if (-not $command) {
        Write-Log "$($tool.Name) est introuvable. Utilisez d abord l option d installation." 'WARN'
        return $false
    }
    if (-not (Confirm-Action "Ouvrir l outil Microsoft $($tool.Name)")) { return $false }
    return (Invoke-Action "Ouverture de $($tool.Name)" {
        Start-Process -FilePath $command.Source -ErrorAction Stop
    })
}

function Start-SysinternalsCenter {
    do {
        Write-Host "`nOUTILS MICROSOFT SYSINTERNALS" -ForegroundColor Cyan
        Write-Host '  [1] Verifier les outils disponibles'
        Write-Host '  [2] Installer un outil avec WinGet'
        Write-Host '  [3] Ouvrir un outil installe'
        Write-Host '  [0] Retour au menu principal'
        switch (Read-Host 'Votre choix') {
            '1' { Show-SysinternalsStatus }
            '2' { Install-SysinternalsTool | Out-Null }
            '3' { Start-SysinternalsTool | Out-Null }
            '0' { return }
            default { Write-Log 'Choix invalide dans le centre Sysinternals.' 'WARN' }
        }
    } while ($true)
}
