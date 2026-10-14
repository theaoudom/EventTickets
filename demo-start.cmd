@echo off
rem Start the Event Tickets demo on Windows (double-click). Needs Java 21.
rem Database: Docker if available, else the PostgreSQL installed on this PC, else the built-in H2 database.
rem Options (from a command prompt):  demo-start.cmd reset   - clean seed data (Docker database)
rem                                   demo-start.cmd h2      - always use the built-in H2 database
set ARGS=-Open
if /I "%~1"=="reset" set ARGS=-Open -Reset
if /I "%~1"=="h2" set ARGS=-Open -Database h2
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.claude\skills\demo\scripts\start.ps1" %ARGS%
pause
