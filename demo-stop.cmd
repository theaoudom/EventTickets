@echo off
rem Stop the Event Tickets demo on Windows (double-click). Also stops PostgreSQL.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.claude\skills\demo\scripts\stop.ps1" -Db
pause
