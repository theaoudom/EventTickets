@echo off
rem Start the Event Tickets demo on Windows (double-click). Needs Java 21.
rem Database: PostgreSQL in Docker if available, else the PostgreSQL installed on this PC.
rem Options (from a command prompt):  demo-start.cmd reset   - clean seed data (Docker database)
set ARGS=-Open
if /I "%~1"=="reset" set ARGS=-Open -Reset
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.claude\skills\demo\scripts\start.ps1" %ARGS%
pause
