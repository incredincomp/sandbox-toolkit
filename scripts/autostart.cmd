@echo off
rem autostart.cmd — Thin launcher. Delegates all install logic to Install-Tools.ps1.
rem This file must remain .cmd because Windows Sandbox LogonCommand requires a direct executable.
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\WDAGUtilityAccount\Desktop\scripts\Install-Tools.ps1"
