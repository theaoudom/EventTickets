# Windows version of stop.sh. Stops only this project's app.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .claude\skills\demo\scripts\stop.ps1 [-Db]
#   -Db also stops the PostgreSQL container.
# Keep this file plain ASCII: Windows PowerShell 5.1 misreads UTF-8 files without a BOM.
param([switch]$Db)

$ErrorActionPreference = 'Continue'
$Root  = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$State = Join-Path $Root 'eventtickets\build\demo'
$portFile = Join-Path $State 'port'
$pidFile  = Join-Path $State 'gradle.pid'

$stopped = $false
if (Test-Path $portFile) {
  $port = (Get-Content $portFile -Raw).Trim()
  $owners = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique
  foreach ($procId in $owners) {
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue).CommandLine
    # Only stop the process if it is this project's app (other projects may use nearby ports)
    if ($cmd -and $cmd -match 'eventtickets') {
      Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
      $stopped = $true
    } else {
      Write-Host "Port $port is used by another program (pid $procId); not touching it."
    }
  }
  Remove-Item $portFile -ErrorAction SilentlyContinue
}
if (Test-Path $pidFile) {
  $gradlePid = (Get-Content $pidFile -Raw).Trim()
  # The saved pid is the gradlew.bat window started by start.ps1; /T also ends its child processes
  taskkill /PID $gradlePid /T /F *> $null
  Remove-Item $pidFile -ErrorAction SilentlyContinue
}
if ($stopped) { Write-Host 'OK App stopped' -ForegroundColor Green } else { Write-Host 'App was not running' }

if ($Db) {
  docker stop eventtickets-pg *> $null
  if ($LASTEXITCODE -eq 0) { Write-Host 'OK PostgreSQL stopped' -ForegroundColor Green } else { Write-Host 'PostgreSQL was not running' }
}
