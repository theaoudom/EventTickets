@echo off
rem Start the Event Tickets demo on Windows (double-click). Needs Java 21 and Docker Desktop.
rem Add  reset  as an argument to restore the seed data:  demo-start.cmd reset
if /I "%~1"=="reset" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.claude\skills\demo\scripts\start.ps1" -Open -Reset
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.claude\skills\demo\scripts\start.ps1" -Open
)
pause
