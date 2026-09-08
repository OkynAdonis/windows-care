@echo off
setlocal
title SCRIPT - Outil Windows complet

rem SCRIPT - Outil Windows complet
rem Propriete : TECH EXCHANGE
rem Contact : +241 77 17 14 32 | techexchange50@gmail.com
rem Ce lanceur ouvre le moteur PowerShell avec les droits administrateur.

fltmc >nul 2>&1
if errorlevel 1 (
    if "%*"=="" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SCRIPT_TOOL.ps1" %*
set "exitCode=%errorlevel%"
if not "%exitCode%"=="0" (
    echo.
    echo L outil a rencontre une erreur. Consultez le dossier data\logs.
    pause
)
exit /b %exitCode%