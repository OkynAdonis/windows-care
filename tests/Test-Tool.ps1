[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $projectRoot 'app\SCRIPT_TOOL.ps1'
$support = Join-Path $projectRoot 'app\State.ps1'
$suiteRoot = Join-Path ([IO.Path]::GetTempPath()) ('windows-care-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $suiteRoot | Out-Null
$script:DataRoot = $suiteRoot
$script:BackupRoot = Join-Path $suiteRoot 'backups'
$script:LogFile = Join-Path $suiteRoot 'test.log'
$script:Session = [guid]::NewGuid().ToString('N')
$script:Simulation = $false
$script:Root = Join-Path $projectRoot 'app'
New-Item -ItemType Directory -Path $script:BackupRoot | Out-Null
$script:passed = 0
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Test($name, [scriptblock]$body) { & $body; $script:passed++; Write-Host "PASS $name" -ForegroundColor Green }
try {
    foreach ($file in @($engine,$support,(Join-Path $projectRoot 'build-release.ps1'))) {
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($file,[ref]$null,[ref]$errors)
        Assert (@($errors).Count -eq 0) "Syntaxe invalide : $file : $errors"
        if ($file -ne (Join-Path $projectRoot 'build-release.ps1')) {
            foreach ($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) {
                . ([scriptblock]::Create($definition.Extent.Text))
            }
        }
    }
    Test 'Native empty output and successful exit' {
        $result = Invoke-NativeCommand "$env:WINDIR\System32\cmd.exe" @('/d','/c','exit 0')
        Assert ($result.Success -and $result.StdOut -eq '' -and $result.StdErr -eq '') 'Empty output must not throw.'
    }
    Test 'Native failure and accepted reboot code' {
        $threw = $false
        try { Invoke-NativeCommand "$env:WINDIR\System32\cmd.exe" @('/d','/c','exit 7') | Out-Null } catch { $threw=$true }
        Assert $threw 'Nonzero exit must throw.'
        $result = Invoke-NativeCommand "$env:WINDIR\System32\cmd.exe" @('/d','/c','exit 7') -AllowFailure
        Assert (-not $result.Success -and $result.ExitCode -eq 7) 'AllowFailure must preserve failure.'
        $result = Invoke-NativeCommand "$env:WINDIR\System32\cmd.exe" @('/d','/c','exit 3010') -SuccessCodes @(0,3010)
        Assert $result.Success 'Accepted reboot code must succeed.'
    }
    Test 'Native argument round trip' {
        $child = Join-Path $suiteRoot 'arguments.ps1'
        Set-Content -LiteralPath $child -Value 'ConvertTo-Json -InputObject @($args) -Compress' -Encoding UTF8
        $expected = @('two words','quote"inside','C:\folder with spaces\','')
        $result = Invoke-NativeCommand "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" (@('-NoProfile','-File',$child) + $expected)
        $actual = $result.StdOut | ConvertFrom-Json
        Assert ($actual.Count -eq $expected.Count) 'Argument count differs.'
        for($i=0;$i -lt $expected.Count;$i++) { Assert ($actual[$i] -ceq $expected[$i]) "Argument $i differs." }
    }
    Test 'Simulation skips mutation and backup but runs diagnostics' {
        $script:Simulation = $true
        try {
            $script:ran = $false
            Invoke-Action 'mutation' { $script:ran=$true } | Out-Null
            Assert (-not $script:ran) 'Mutation ran in simulation.'
            $before = @(Get-ChildItem $script:BackupRoot).Count
            New-StateBackup -Category Power
            Assert (@(Get-ChildItem $script:BackupRoot).Count -eq $before) 'Simulation created backup.'
            Invoke-Action 'diagnostic' -ReadOnly { $script:ran=$true } | Out-Null
            Assert $script:ran 'Diagnostic was skipped.'
            function Invoke-NativeCommand { throw 'Native command reached in simulation.' }
            Set-Performance -Mode Ultimate
            Set-Privacy
            Set-SearchPrivacy
            Repair-Update
            Register-MaintenanceTask
            Clean-System
        } finally { $script:Simulation=$false }
    }
    Test 'Action failure does not report success' {
        $result = Invoke-Action 'expected failure' { throw 'simulated failure' }
        Assert ($result -eq $false) 'Failure returned success.'
    }
    Test 'Backup failure prevents registry mutation' {
        function Confirm-Action { $true }
        function New-StateBackup { throw 'backup unavailable' }
        function New-ItemProperty { throw 'MUTATION REACHED' }
        Set-SearchPrivacy
        $last = Get-Content $script:LogFile -Tail 1
        Assert ($last -like '*backup unavailable*') 'Backup failure was not propagated.'
    }
    Test 'Backups are unique and contain complete power state' {
        function Get-ActivePowerPlanGuid { '381b4222-f694-41f0-9685-ff5bb260df2e' }
        $first = New-StateBackup -Category Power
        $second = New-StateBackup -Category Power
        Assert ($first -ne $second) 'Backup overwritten.'
        $state = Import-Clixml (Join-Path $first 'state.xml')
        Assert ($state.Complete -and $state.SchemaVersion -eq 2 -and $state.PowerGuid) 'Invalid power backup.'
    }
    Test 'Power selection is independent of language and list order' {
        $script:active='381b4222-f694-41f0-9685-ff5bb260df2e'
        $script:duplicated=$false
        function Confirm-Action { $true }
        function New-StateBackup { 'mock backup' }
        function Save-TemporaryPowerPlan { }
        function Get-ActivePowerPlanGuid { $script:active }
        function Invoke-NativeCommand {
            param($FilePath,$Arguments,$Title)
            switch ($Arguments[0]) {
                '-list' { [pscustomobject]@{StdOut="GUID: 381b4222-f694-41f0-9685-ff5bb260df2e (Equilibre)`nGUID: 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c (Performances elevees)"} }
                '-duplicatescheme' { $script:duplicated=$true; Assert ($Arguments[1] -eq $Arguments[2]) 'Destination GUID missing.' }
                '-setactive' { $script:active=$Arguments[1] }
                default { throw 'Unexpected command.' }
            }
        }
        Set-Performance High
        Assert ($script:active -eq '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -and -not $script:duplicated) 'Wrong existing plan.'
        Set-Performance Ultimate
        Assert ($script:active -eq 'e9a42b02-d5df-448d-aa00-03f14749eb61' -and $script:duplicated) 'Wrong new plan.'
    }
    Test 'Temporary power restore preserves original plan across profiles' {
        Save-TemporaryPowerPlan '381b4222-f694-41f0-9685-ff5bb260df2e' Balanced
        Save-TemporaryPowerPlan 'e9a42b02-d5df-448d-aa00-03f14749eb61' Ultimate
        $state=Get-Content (Join-Path $suiteRoot 'temporary-power-plan.json') -Raw | ConvertFrom-Json
        Assert ($state.Guid -eq '381b4222-f694-41f0-9685-ff5bb260df2e') 'Original plan overwritten.'
    }
    Test 'DNS restore matches adapter GUID and preserves automatic mode' {
        $script:restored = @()
        $script:snapshotTaken = $false
        $fixture = Join-Path $suiteRoot 'dns-restore'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        [pscustomobject]@{SchemaVersion=2;Complete=$true;Category='DNS';Computer=$env:COMPUTERNAME;UserSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;AdapterGuid='11111111-1111-1111-1111-111111111111';DNS=@([pscustomobject]@{Family='IPv4';Automatic=$true;Servers=@('192.0.2.1')},[pscustomobject]@{Family='IPv6';Automatic=$false;Servers=@('2001:db8::1')})} | Export-Clixml (Join-Path $fixture 'state.xml')
        function Select-Backup { Get-Item $fixture }
        function Confirm-Action { $true }
        function New-StateBackup { $script:snapshotTaken=$true }
        function Get-NetAdapter { [pscustomobject]@{InterfaceGuid='11111111-1111-1111-1111-111111111111';ifIndex=42} }
        function Get-DnsClientServerAddress { param($InterfaceIndex,$AddressFamily,$ErrorAction); Assert ($InterfaceIndex -eq 42) 'Wrong interface.'; [pscustomobject]@{Family=$AddressFamily} }
        function Set-DnsClientServerAddress {
            param([Parameter(ValueFromPipeline=$true)]$InputObject,[switch]$ResetServerAddresses,$ServerAddresses)
            process { Assert $script:snapshotTaken 'Restore wrote before backup.'; $script:restored += [pscustomobject]@{Family=$InputObject.Family;Automatic=[bool]$ResetServerAddresses;Servers=$ServerAddresses} }
        }
        Restore-State
        Assert ($script:restored.Count -eq 2 -and $script:restored[0].Automatic -and $script:restored[1].Servers[0] -eq '2001:db8::1') 'DNS mode or addresses changed.'
        $script:restored=@()
        function Get-NetAdapter { [pscustomobject]@{InterfaceGuid='22222222-2222-2222-2222-222222222222';ifIndex=42} }
        Restore-State
        Assert ($script:restored.Count -eq 0) 'Restore used a different adapter.'
    }
    Test 'Registry restore removes new values and restores existing values' {
        $script:registryWrites=@()
        $fixture=Join-Path $suiteRoot 'registry-restore'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        $path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
        [pscustomobject]@{SchemaVersion=2;Complete=$true;Category='Search';Computer=$env:COMPUTERNAME;UserSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;Registry=@([pscustomobject]@{Path=$path;Name='DisableWebSearch';Exists=$false},[pscustomobject]@{Path=$path;Name='AllowCloudSearch';Exists=$true;Value=1;Kind='DWord'})} | Export-Clixml (Join-Path $fixture 'state.xml')
        function Select-Backup { [pscustomobject]@{FullName=$fixture;Name='fixture'} }
        function Confirm-Action { $true }
        function New-StateBackup { }
        function Test-Path { $true }
        function Get-Item {
            $key=[pscustomobject]@{}
            $key | Add-Member ScriptMethod GetValueNames { @('DisableWebSearch','AllowCloudSearch') }
            $key | Add-Member ScriptMethod Close { }
            $key
        }
        function New-ItemProperty { param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force,$ErrorAction); $script:registryWrites += "set:$Name=$Value" }
        function Remove-ItemProperty { param($LiteralPath,$Name,$ErrorAction); $script:registryWrites += "remove:$Name" }
        Restore-State
        Assert ('remove:DisableWebSearch' -in $script:registryWrites -and 'set:AllowCloudSearch=1' -in $script:registryWrites) 'Registry state not restored.'
    }
    Test 'Update failure restarts previously running services' {
        $script:restarted=@()
        function Confirm-Action { $true }
        function Get-Service { @([pscustomobject]@{Name='wuauserv';Status='Running'},[pscustomobject]@{Name='bits';Status='Stopped'}) }
        function Stop-Service { param($Name,[switch]$Force,$ErrorAction); if($Name -eq 'bits'){throw 'simulated stop failure'} }
        function Start-Service { param($Name,$ErrorAction); $script:restarted += $Name }
        Repair-Update
        Assert ($script:restarted.Count -eq 1 -and $script:restarted[0] -eq 'wuauserv') 'Original service state not recovered.'
        Assert ((Get-Content $script:LogFile -Tail 1) -like '*simulated stop failure*') 'Update failure hidden.'
    }
    Test 'Weekly task uses noninteractive report mode' {
        $script:taskArguments=$null; $script:taskRegistered=$false
        function Confirm-Action { $true }
        function New-ScheduledTaskAction { param($Execute,$Argument,$WorkingDirectory); $script:taskArguments=$Argument; [pscustomobject]@{} }
        function New-ScheduledTaskTrigger { param([switch]$Weekly,$DaysOfWeek,$At); [pscustomobject]@{} }
        function New-ScheduledTaskPrincipal { param($UserId,$LogonType,$RunLevel); Assert ($LogonType -eq 'Interactive' -and $RunLevel -eq 'Highest') 'Wrong task principal.'; [pscustomobject]@{} }
        function New-ScheduledTaskSettingsSet { param([switch]$StartWhenAvailable,$ExecutionTimeLimit); [pscustomobject]@{} }
        function Register-ScheduledTask { param($TaskName,$Action,$Trigger,$Principal,$Settings,[switch]$Force,$ErrorAction); $script:taskRegistered=$true }
        Register-MaintenanceTask
        Assert ($script:taskRegistered -and $script:taskArguments -like '*-NonInteractive*-ReportOnly' -and $script:taskArguments -notlike '*-DryRun*') 'Task does not run report.'
    }
    Test 'Backup selection accepts index 10' {
        function Get-ChildItem { 1..12 | ForEach-Object { [pscustomobject]@{Name=('{0:00}' -f $_)} } }
        function Read-Host { '10' }
        $selected=Select-Backup
        Assert ($selected.Name -eq '03') 'Multi-digit index selected incorrectly.'
    }
    Test 'Temporary cleanup rejects paths outside root and protects tool data' {
        $temporary=Join-Path $suiteRoot 'cleanup'
        New-Item -ItemType Directory -Path $temporary | Out-Null
        $file=Join-Path $temporary 'sample.txt'
        Set-Content -LiteralPath $file -Value 'sample'
        $failed=$false
        try { Remove-TemporaryEntry -Item (Get-Item $file) -Root (Join-Path $suiteRoot 'elsewhere') } catch { $failed=$true }
        Assert ($failed -and (Test-Path $file)) 'Cleanup escaped root.'
        Remove-TemporaryEntry -Item (Get-Item $file) -Root $temporary
        Assert (-not (Test-Path $file)) 'Cleanup did not remove allowed file.'
        $failed=$false
        try { Remove-TemporaryEntry -Item (Get-Item $suiteRoot) -Root ([IO.Path]::GetTempPath()) } catch { $failed=$true }
        Assert ($failed -and (Test-Path $suiteRoot)) 'Cleanup removed tool data.'
    }
    Test 'Report-only entry point exits without entering menu' {
        $ast=[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$null,[ref]$null)
        $branch=$ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.IfStatementAst] -and $_.Extent.Text.StartsWith('if ($ReportOnly)') }
        $child=Join-Path $suiteRoot 'report-entry.ps1'
        $source='$ReportOnly=$true; function New-HealthReport { Write-Output "REPORT_CREATED" }; function Write-Log { param($Message,$Level); Write-Output $Message }; ' + $branch.Extent.Text + '; throw "MENU_REACHED"'
        Set-Content -LiteralPath $child -Value $source -Encoding UTF8
        $result=Invoke-NativeCommand "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" @('-NoProfile','-NonInteractive','-File',$child)
        Assert ($result.Success -and $result.StdOut.Trim() -eq 'REPORT_CREATED') 'Report-only entry entered menu.'
    }
    Test 'Menu quit exits after one prompt' {
        $ast=[Management.Automation.Language.Parser]::ParseFile($engine,[ref]$null,[ref]$null)
        $loop=$ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.DoWhileStatementAst] }
        function Show-Menu { }
        function Read-Host { $script:prompts++; if($script:prompts -gt 1){throw 'Menu loop did not exit.'}; '0' }
        $script:prompts=0
        & ([scriptblock]::Create($loop.Extent.Text))
        Assert ($script:prompts -eq 1) 'Quit did not exit.'
    }
    Test 'Report generates HTML from diagnostic data' {
        function Get-HealthScore { [pscustomobject]@{Score=70;Checks=[ordered]@{Stockage=70};FreePercent=12} }
        New-HealthReport
        $report=Get-Content (Join-Path $suiteRoot "rapport-$($script:Session).html") -Raw
        Assert ($report -like '*70/100*' -and $report -like '*Stockage*') 'Report content missing.'
    }
    Write-Host "$script:passed tests passed. No Windows configuration changed."
} finally {
    $resolved=[IO.Path]::GetFullPath($suiteRoot)
    $tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'windows-care-tests-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
