[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('windows-care-launcher-' + [guid]::NewGuid().ToString('N'))
$fixture=Join-Path $fixtureRoot "Windows Care & l'essai"
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $projectRoot 'app\SCRIPT_TOOL.bat') -Destination $fixture
    $stub=@'
param([switch]$DryRun,[switch]$Restore,[switch]$ReportOnly,[switch]$RemoveMaintenanceTask)
Write-Output "FLAGS DryRun=$DryRun Restore=$Restore ReportOnly=$ReportOnly Remove=$RemoveMaintenanceTask"
if ($ReportOnly -and $Restore) { exit 7 }
exit 0
'@
    Set-Content -LiteralPath (Join-Path $fixture 'SCRIPT_TOOL.ps1') -Value $stub -Encoding UTF8
    $bat=Join-Path $fixture 'SCRIPT_TOOL.bat'
    $cases=@(
        @{Arguments='-ReportOnly';Exit=0;Text='ReportOnly=True'},
        @{Arguments='-DryRun';Exit=0;Text='DryRun=True'},
        @{Arguments='-ReportOnly -Restore';Exit=7;Text='Restore=True'},
        @{Arguments='-ReportOnly -Unknown';Exit=2;Text='Argument inconnu'}
    )
    foreach($case in $cases) {
        $start=[Diagnostics.ProcessStartInfo]::new()
        $start.FileName=$env:COMSPEC
        $start.Arguments='/d /s /c ""' + $bat + '" ' + $case.Arguments + '"'
        $start.UseShellExecute=$false
        $start.CreateNoWindow=$true
        $start.RedirectStandardOutput=$true
        $start.RedirectStandardError=$true
        $process=[Diagnostics.Process]::Start($start)
        $stdout=$process.StandardOutput.ReadToEndAsync()
        $stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(20000)){ $process.Kill(); throw 'Le lanceur ne termine pas sans interaction.' }
        $text=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
        if($process.ExitCode -ne $case.Exit -or -not $text.Contains($case.Text)){throw "Lanceur : $($case.Arguments), code $($process.ExitCode), sortie $text"}
        Write-Host "PASS launcher $($case.Arguments), path with spaces, ampersand and apostrophe"
        $process.Dispose()
    }
    Write-Host '4 launcher scenarios passed. No elevation or Windows configuration changes.'
} finally {
    $resolved=[IO.Path]::GetFullPath($fixtureRoot)
    $tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if($resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'windows-care-launcher-*'){Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue}
}
