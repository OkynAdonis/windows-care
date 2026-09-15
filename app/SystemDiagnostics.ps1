# Diagnostics detailles en lecture seule pour identifier les causes de lenteur et d instabilite.

function Get-SystemResourceSnapshot {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $processor = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
    $disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)
    [pscustomobject]@{
        Windows = "$($os.Caption) $($os.Version)"
        LastBoot = $os.LastBootUpTime
        MemoryTotalGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
        MemoryFreeGB = [math]::Round($os.FreePhysicalMemory * 1KB / 1GB, 1)
        Processor = ($processor.Name -join ' / ')
        LogicalProcessors = ($processor | Measure-Object NumberOfLogicalProcessors -Sum).Sum
        Disks = @($disks | Select-Object DeviceID,VolumeName,@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}},@{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,1)}},@{N='FreePercent';E={if($_.Size){[math]::Round(100*$_.FreeSpace/$_.Size,1)}else{0}}})
    }
}

function Show-SystemResourceSnapshot {
    Invoke-Action 'Vue d ensemble des ressources systeme' -ReadOnly {
        $result = Get-SystemResourceSnapshot
        $result | Select-Object Windows,LastBoot,Processor,LogicalProcessors,MemoryTotalGB,MemoryFreeGB | Format-List
        $result.Disks | Format-Table -AutoSize
    } | Out-Null
}

function Show-HeavyProcesses {
    Invoke-Action 'Processus utilisant le plus de ressources' -ReadOnly {
        Write-Host "`nPROCESSEURS - cumul depuis le lancement" -ForegroundColor Cyan
        Get-Process -ErrorAction Stop | Sort-Object CPU -Descending | Select-Object -First 10 Name,Id,@{N='CPUSeconds';E={if($null -eq $_.CPU){$null}else{[math]::Round($_.CPU,1)}}},@{N='MemoryMB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
        Write-Host "`nMEMOIRE ACTUELLE" -ForegroundColor Cyan
        Get-Process -ErrorAction Stop | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name,Id,@{N='MemoryMB';E={[math]::Round($_.WorkingSet64/1MB,1)}},@{N='CPUSeconds';E={if($null -eq $_.CPU){$null}else{[math]::Round($_.CPU,1)}}} | Format-Table -AutoSize
    } | Out-Null
}

function Get-RecentCriticalEvents {
    param([ValidateRange(1,168)][int]$Hours = 48)
    $start = (Get-Date).AddHours(-$Hours)
    @(Get-WinEvent -FilterHashtable @{LogName=@('System','Application');Level=@(1,2);StartTime=$start} -MaxEvents 40 -ErrorAction Stop |
        Select-Object TimeCreated,LogName,Id,ProviderName,LevelDisplayName,@{N='Message';E={([string]$_.Message -replace '[\r\n]+',' ').Trim()}})
}

function Show-RecentCriticalEvents {
    Invoke-Action 'Erreurs critiques recentes de Windows' -ReadOnly {
        $events = @(Get-RecentCriticalEvents)
        if ($events.Count) { $events | Format-Table TimeCreated,LogName,Id,ProviderName,LevelDisplayName -AutoSize }
        else { Write-Log 'Aucune erreur ou evenement critique trouve sur les dernieres 48 heures.' 'OK' }
    } | Out-Null
}

function Show-SystemStability {
    Invoke-Action 'Historique de stabilite Windows' -ReadOnly {
        $records = @(Get-CimInstance Win32_ReliabilityRecords -ErrorAction Stop | Sort-Object TimeGenerated -Descending | Select-Object -First 30 TimeGenerated,SourceName,ProductName,EventIdentifier,Message)
        if ($records.Count) { $records | Format-Table TimeGenerated,SourceName,ProductName,EventIdentifier -AutoSize }
        else { Write-Log 'Aucun historique de fiabilite disponible.' 'WARN' }
    } | Out-Null
}

function Export-AdvancedSystemDiagnostic {
    Invoke-Action 'Export du diagnostic systeme avance' -ReadOnly {
        $report = Join-Path $script:DataRoot "system-diagnostic-$($script:Session).json"
        $payload = [ordered]@{
            CreatedAt = (Get-Date).ToString('o')
            Resources = Get-SafeDiagnosticValue 'Ressources' { Get-SystemResourceSnapshot }
            CriticalEvents = Get-SafeDiagnosticValue 'Evenements critiques' { @(Get-RecentCriticalEvents) }
            Drivers = Get-SafeDiagnosticValue 'Pilotes' { @(Get-DriverIssues) }
            Reboot = Get-SafeDiagnosticValue 'Redemarrage' { Get-PendingRebootState }
        }
        [IO.File]::WriteAllText($report,($payload | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        Write-Log "Diagnostic systeme avance : $report" 'OK'
    } | Out-Null
}

function Start-AdvancedSystemDiagnosticCenter {
    do {
        Write-Host "`nDIAGNOSTIC SYSTEME AVANCE" -ForegroundColor Cyan
        Write-Host '  [1] Vue d ensemble CPU, memoire et disques'
        Write-Host '  [2] Processus les plus lourds'
        Write-Host '  [3] Erreurs critiques des dernieres 48 heures'
        Write-Host '  [4] Historique de stabilite Windows'
        Write-Host '  [5] Exporter le diagnostic complet'
        Write-Host '  [0] Retour au menu principal'
        switch (Read-Host 'Votre choix') {
            '1' { Show-SystemResourceSnapshot }
            '2' { Show-HeavyProcesses }
            '3' { Show-RecentCriticalEvents }
            '4' { Show-SystemStability }
            '5' { Export-AdvancedSystemDiagnostic }
            '0' { return }
            default { Write-Log 'Choix invalide dans le diagnostic systeme avance.' 'WARN' }
        }
    } while ($true)
}
