@echo off
setlocal
title Windows Care - TECH EXCHANGE
set "WC_ENGINE=%~dp0SCRIPT_TOOL.ps1"
set "WC_FLAGS="
set "WC_REPORT="
:parse
if "%~1"=="" goto launch
if /i "%~1"=="-DryRun" goto accept
if /i "%~1"=="-Restore" goto accept
if /i "%~1"=="-RemoveMaintenanceTask" goto accept
if /i "%~1"=="-ReportOnly" (
    set "WC_REPORT=1"
    goto accept
)
echo Argument inconnu. Options : -DryRun -Restore -ReportOnly -RemoveMaintenanceTask
exit /b 2
:accept
set "WC_FLAGS=%WC_FLAGS% %~1"
shift
goto parse
:launch
if defined WC_REPORT goto direct
fltmc >nul 2>&1
if not errorlevel 1 goto direct
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $q=[char]34; $a='-NoProfile -ExecutionPolicy Bypass -File '+$q+$env:WC_ENGINE+$q+$env:WC_FLAGS; $p=Start-Process -FilePath ($PSHOME+'\powershell.exe') -ArgumentList $a -Verb RunAs -Wait -PassThru; exit $p.ExitCode } catch { Write-Host ('Lancement annule ou impossible : '+$_.Exception.Message); exit 1 }"
goto result
:direct
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WC_ENGINE%" %WC_FLAGS%
:result
set "exitCode=%errorlevel%"
if not "%exitCode%"=="0" (
    echo.
    echo L outil a rencontre une erreur. Consultez data\logs a cote du moteur.
    if not defined WC_REPORT pause
)
exit /b %exitCode%