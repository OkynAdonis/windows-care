# Essai d integration opt-in : cree une tache temporaire, puis la supprime.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$script:Root=Join-Path $projectRoot 'app'
$script:DataRoot=[IO.Path]::GetFullPath($EvidenceDirectory)
$script:LogRoot=Join-Path $script:DataRoot 'logs'
$script:LogFile=Join-Path $script:LogRoot 'scheduled-test.log'
$script:Simulation=$false
New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:Root 'SCRIPT_TOOL.ps1'),[ref]$null,[ref]$null)
foreach($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) { . ([scriptblock]::Create($definition.Extent.Text)) }
if(-not (Test-Administrator)){throw 'Cet essai de tache elevee necessite une console administrateur.'}
function Confirm-Action { $true }
$taskName='WindowsCare-Test-' + [guid]::NewGuid().ToString('N')
$started=Get-Date
try {
    Register-MaintenanceTask -TaskName $taskName
    if(-not $script:LastActionSucceeded){throw 'Creation de la tache de test en echec.'}
    $task=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    if($task.Actions.Arguments -notlike '*-NonInteractive*-ReportOnly'){throw 'Arguments de la tache incorrects.'}
    Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $deadline=(Get-Date).AddSeconds(90)
    do {
        Start-Sleep -Seconds 2
        $info=Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
        $task=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        if($info.LastRunTime -ge $started.AddSeconds(-1) -and $task.State -eq 'Ready' -and $info.LastTaskResult -ne 267009){break}
    }while((Get-Date) -lt $deadline)
    $reports=@(Get-ChildItem -LiteralPath $script:DataRoot -Filter 'rapport-*.html' | Where-Object LastWriteTime -ge $started)
    if($info.LastRunTime -lt $started.AddSeconds(-1) -or $task.State -ne 'Ready' -or $info.LastTaskResult -ne 0 -or -not $reports.Count){throw "Rapport planifie incomplet : resultat $($info.LastTaskResult), etat $($task.State), rapports $($reports.Count)."}
    [pscustomobject]@{Test='ScheduledReport';Passed=$true;WindowsBuild=[Environment]::OSVersion.Version.ToString();LastTaskResult=$info.LastTaskResult;ReportCount=$reports.Count;CompletedAt=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:DataRoot 'scheduled-result.json') -Encoding UTF8
    Write-Host 'PASS real scheduled report, noninteractive, result 0.'
}catch{
    [pscustomobject]@{Test='ScheduledReport';Passed=$false;Error=$_.Exception.Message;Stack=$_.ScriptStackTrace;LastTaskResult=$info.LastTaskResult;TaskState=$task.State;CompletedAt=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:DataRoot 'scheduled-result.json') -Encoding UTF8
    throw
}finally{
    $task=Get-ScheduledTask -ErrorAction Stop | Where-Object {$_.TaskName -eq $taskName -and $_.TaskPath -eq '\'}
    if($task){
        if($task.State -eq 'Running'){Stop-ScheduledTask -TaskName $taskName -ErrorAction Stop}
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
    }
}
