# Diagnostic reseau detaille sans reinitialisation automatique.

function Show-NetworkConfigurationDetail {
    Invoke-Action 'Configuration reseau complete' -ReadOnly {
        Invoke-NativeCommand 'ipconfig.exe' @('/all') 'Configuration IP complete' | Out-Null
        Invoke-NativeCommand 'route.exe' @('print','-4') 'Table de routage IPv4' | Out-Null
    } | Out-Null
}

function Show-NetworkProxyState {
    Invoke-Action 'Etat des proxys Windows' -ReadOnly {
        Invoke-NativeCommand 'netsh.exe' @('winhttp','show','proxy') 'Proxy WinHTTP' | Out-Null
        $internetSettings = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
        [pscustomobject]@{UserProxyEnabled=[bool]$internetSettings.ProxyEnable;UserProxy=$internetSettings.ProxyServer;AutoConfig=$internetSettings.AutoConfigURL} | Format-List
    } | Out-Null
}

function Test-NetworkLatency {
    Invoke-Action 'Latence et pertes reseau' -ReadOnly {
        foreach ($target in @('1.1.1.1','8.8.8.8','www.microsoft.com')) {
            try {
                $answers = @(Test-Connection -ComputerName $target -Count 3 -ErrorAction Stop)
                $average = ($answers | Measure-Object ResponseTime -Average).Average
                [pscustomobject]@{Target=$target;Replies=$answers.Count;AverageMs=[math]::Round($average,1);Status='OK'}
            } catch { [pscustomobject]@{Target=$target;Replies=0;AverageMs=$null;Status=$_.Exception.Message} }
        }
    } | Out-Null
}

function Test-DnsResponseTimes {
    Invoke-Action 'Temps de reponse DNS' -ReadOnly {
        foreach ($name in @('www.microsoft.com','github.com')) {
            $clock = [Diagnostics.Stopwatch]::StartNew()
            try {
                $answers = @(Resolve-DnsName $name -Type A -DnsOnly -ErrorAction Stop)
                $clock.Stop()
                [pscustomobject]@{Name=$name;Milliseconds=$clock.ElapsedMilliseconds;Addresses=@($answers | Where-Object IPAddress | ForEach-Object IPAddress) -join ', ';Status='OK'}
            } catch {
                $clock.Stop()
                [pscustomobject]@{Name=$name;Milliseconds=$clock.ElapsedMilliseconds;Addresses='';Status=$_.Exception.Message}
            }
        }
    } | Out-Null
}

function Show-AdvancedNetworkAdapters {
    Invoke-Action 'Interfaces physiques et virtuelles' -ReadOnly {
        Get-NetAdapter -IncludeHidden -ErrorAction Stop | Select-Object Name,InterfaceDescription,Status,LinkSpeed,MacAddress,DriverInformation,Virtual | Format-Table -AutoSize
    } | Out-Null
}

function Start-AdvancedNetworkCenter {
    do {
        Write-Host "`nDIAGNOSTIC RESEAU AVANCE" -ForegroundColor Cyan
        Write-Host '  [1] Diagnostic par couches'
        Write-Host '  [2] Configuration IP et routes'
        Write-Host '  [3] Proxys utilisateur et WinHTTP'
        Write-Host '  [4] Latence et pertes vers plusieurs cibles'
        Write-Host '  [5] Temps de reponse DNS'
        Write-Host '  [6] Interfaces physiques et virtuelles'
        Write-Host '  [7] Reinitialisation reseau avec confirmation'
        Write-Host '  [0] Retour au menu principal'
        switch (Read-Host 'Votre choix') {
            '1' { Show-NetworkDiagnostic }
            '2' { Show-NetworkConfigurationDetail }
            '3' { Show-NetworkProxyState }
            '4' { Test-NetworkLatency }
            '5' { Test-DnsResponseTimes }
            '6' { Show-AdvancedNetworkAdapters }
            '7' { Reset-Network }
            '0' { return }
            default { Write-Log 'Choix invalide dans le diagnostic reseau avance.' 'WARN' }
        }
    } while ($true)
}
