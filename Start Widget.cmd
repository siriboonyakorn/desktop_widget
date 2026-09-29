@echo off
start "" powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0ClockWidget.ps1"
