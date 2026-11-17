@echo off
rem SincronizzaFoto launcher - double click to start. No installation needed (Windows 10/11).
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Hidden -File "%~dp0SincronizzaFoto.ps1"
