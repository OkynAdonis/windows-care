# Diagnostic local : les mesures indisponibles sont exclues du score.
function New-HealthCheck {
    param([string]$Name,[scriptblock]$Measure)
    try {
        $result = & $Measure
        if (-not $result -or $null -eq $result.Score) { throw 'La mesure ne fournit pas de resultat exploitable.' }
        [pscustomobject]@{Name=$Name;Status=$(if ($result.Score -ge 80) {'OK'} else {'Attention'});Score=[int]$result.Score;Detail=$result.Detail;Recommendation=$result.Recommendation}
    } catch {
        [pscustomobject]@{Name=$Name;Status='Indisponible';Score=$null;Detail=$_.Exception.Message;Recommendation='Verifier la disponibilite de cette source et les droits de lecture ; aucune panne deduite de cette absence.'}
    }
}
function Get-HealthScore {
    $freePercent = $null
    $records = @(
        New-HealthCheck 'Stockage' {
            $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -OperationTimeoutSec 15 -ErrorAction Stop
            if (-not $disk -or $disk.Size -le 0 -or $null -eq $disk.FreeSpace) { throw 'Capacite du disque systeme indisponible.' }
            $percent = [math]::Round(100 * $disk.FreeSpace / $disk.Size,1)
            if ($percent -lt 0 -or $percent -gt 100) { throw 'Mesure de stockage incoherente.' }
            [pscustomobject]@{Score=$(if($percent -ge 20){100}elseif($percent -ge 10){70}else{35});Detail="$percent % libres sur le disque systeme. Seuils : 20 % et 10 %.";Recommendation=$(if($percent -lt 20){'Examiner les fichiers volumineux et liberer de l espace sans supprimer les sauvegardes.'}else{'Espace libre suffisant selon ce critere.'})}
        }
        New-HealthCheck 'Demarrage' {
            $items = @(Get-CimInstance Win32_StartupCommand -OperationTimeoutSec 15 -ErrorAction Stop)
            [pscustomobject]@{Score=$(if($items.Count -le 8){100}else{65});Detail="$($items.Count) commandes de demarrage declarees. Ce nombre ne mesure pas leur impact reel.";Recommendation=$(if($items.Count -gt 8){'Examiner le rapport de demarrage ; ne desactiver que les programmes connus et non indispensables.'}else{'Consulter le Gestionnaire des taches si le demarrage reste lent.'})}
        }
        New-HealthCheck 'Defender' {
            $defender = Get-MpComputerStatus -ErrorAction Stop
            if (-not $defender -or $null -eq $defender.AntivirusEnabled -or $null -eq $defender.RealTimeProtectionEnabled) { throw 'Etat de Microsoft Defender indisponible.' }
            if (-not $defender.AntivirusEnabled) {
                $others = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -OperationTimeoutSec 15 -ErrorAction Stop | Where-Object displayName -notmatch '^(Microsoft|Windows) Defender$')
                if ($others.Count) { throw 'Un autre antivirus est declare. Son etat ne peut pas etre certifie par ce diagnostic Defender.' }
            }
            $enabled = $defender.AntivirusEnabled -and $defender.RealTimeProtectionEnabled
            [pscustomobject]@{Score=$(if($enabled){100}else{35});Detail="Antivirus Defender actif : $($defender.AntivirusEnabled). Protection temps reel : $($defender.RealTimeProtectionEnabled).";Recommendation=$(if($enabled){'Verifier regulierement les mises a jour dans Securite Windows.'}else{'Ouvrir Securite Windows pour verifier le fournisseur antivirus et la protection temps reel.'})}
        }
        New-HealthCheck 'Pare-feu' {
            $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
            if (-not $profiles.Count -or @($profiles | Where-Object {$null -eq $_.Enabled}).Count) { throw 'Profils de pare-feu indisponibles.' }
            $enabled = @($profiles | Where-Object {$_.Enabled -eq $true}).Count
            [pscustomobject]@{Score=$(if($enabled -eq $profiles.Count){100}else{30});Detail="$enabled profils actives sur $($profiles.Count). Controle de configuration de tous les profils, pas un test de trafic.";Recommendation=$(if($enabled -eq $profiles.Count){'Conserver le pare-feu actif.'}else{'Verifier les profils desactives dans Securite Windows et les politiques de votre organisation.'})}
        }
        New-HealthCheck 'Reseau local' {
            $adapters = @(Get-NetAdapter -ErrorAction Stop)
            if (-not $adapters.Count) { throw 'Aucune interface reseau detectee.' }
            $active = @($adapters | Where-Object Status -eq 'Up').Count
            [pscustomobject]@{Score=$(if($active){100}else{40});Detail="$active interfaces actives. La connexion Internet, le debit et la resolution DNS ne sont pas testes.";Recommendation=$(if($active){'En cas de probleme Internet, verifier le routeur et tester la resolution DNS avant une reinitialisation.'}else{'Verifier le mode avion, le Wi-Fi et le cable reseau.'})}
        }
    )
    $measured = @($records | Where-Object {$null -ne $_.Score})
    $checks = [ordered]@{}
    foreach ($record in $records) { $checks[$record.Name] = $record.Score }
    $score = if ($measured.Count -ge 3) { [math]::Round(($measured | Measure-Object Score -Average).Average) } else { $null }
    [pscustomobject]@{Score=$score;Checks=$checks;Records=$records;MeasuredCount=$measured.Count;TotalCount=$records.Count;IsPartial=($measured.Count -lt $records.Count);FreePercent=$freePercent}
}
function Show-HealthScore {
    $health = Get-HealthScore
    $label = if ($null -eq $health.Score) { 'Non calculable (moins de 3 mesures disponibles)' } else { "$($health.Score)/100" }
    Write-Host "`nINDICATEUR DE SANTE : $label" -ForegroundColor Cyan
    Write-Host "Couverture : $($health.MeasuredCount)/$($health.TotalCount) mesures. Moyenne indicative, pas une certification de securite."
    foreach ($record in $health.Records) {
        $value = if ($null -eq $record.Score) { 'N/D' } else { "$($record.Score)/100" }
        Write-Host "$($record.Name) : $value - $($record.Status)"
        Write-Host "  $($record.Detail)"
        Write-Host "  Conseil : $($record.Recommendation)"
    }
}
function New-HealthReport {
    $health = Get-HealthScore
    $encode = { param($value) [Net.WebUtility]::HtmlEncode([string]$value) }
    $score = if ($null -eq $health.Score) { 'Non calculable : moins de 3 mesures disponibles' } else { "$($health.Score)/100" }
    $rows = ($health.Records | ForEach-Object {
        $value = if ($null -eq $_.Score) { 'N/D' } else { "$($_.Score)/100" }
        "<tr><th scope='row'>$(& $encode $_.Name)</th><td>$value - $(& $encode $_.Status)</td><td>$(& $encode $_.Detail)<br><strong>Conseil :</strong> $(& $encode $_.Recommendation)</td></tr>"
    }) -join "`n"
    $report = Join-Path $script:DataRoot ("rapport-" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.html')
    $html = @"
<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Rapport Windows Care</title>
<style>body{font-family:Segoe UI,Arial;background:#eef2f5;color:#17212b;max-width:1000px;margin:24px auto;padding:16px}main{background:white;padding:24px}h1{color:#0b6670}table{width:100%;border-collapse:collapse}th,td{padding:12px;border:1px solid #dde4e8;text-align:left;overflow-wrap:anywhere}.table-wrap{overflow:auto}footer{margin-top:24px}</style></head>
<body><main><h1>Rapport Windows Care</h1><p>TECH EXCHANGE | $([datetime]::Now.ToString('dd/MM/yyyy HH:mm'))</p><h2>Indicateur : $score</h2><p>Couverture : $($health.MeasuredCount)/$($health.TotalCount) mesures. Les mesures indisponibles sont exclues. Moyenne a poids egaux, calculee a partir de 3 mesures disponibles ; aucune certification de securite ou de performance.</p><div class="table-wrap"><table><thead><tr><th scope="col">Categorie</th><th scope="col">Resultat</th><th scope="col">Mesure et recommandation</th></tr></thead><tbody>$rows</tbody></table></div><footer>Rapport local. Relire les details avant tout partage. Contact : techexchange50@gmail.com</footer></main></body></html>
"@
    Set-Content -LiteralPath $report -Value $html -Encoding UTF8 -ErrorAction Stop
    Write-Log "Rapport HTML cree : $report" 'OK'
    if ($health.IsPartial) { Write-Log 'Rapport partiel : certaines mesures sont indisponibles.' 'WARN' }
    if ($health.MeasuredCount -eq 0) { throw "Aucune mesure disponible. Rapport explicatif cree : $report" }
}
