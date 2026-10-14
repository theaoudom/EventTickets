# Windows version of start.sh: Docker -> PostgreSQL (port 5433) -> Spring Boot app -> prints the demo URL.
# Usage (from the repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .claude\skills\demo\scripts\start.ps1 [-Open] [-Reset] [-Port 8095]
#   -Reset deletes the database container first, so Flyway recreates the tables and the original seed data.
# Keep this file plain ASCII: Windows PowerShell 5.1 misreads UTF-8 files without a BOM.
param([switch]$Open, [switch]$Reset, [int]$Port = 0)

$ErrorActionPreference = 'Continue'
$Root  = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$App   = Join-Path $Root 'eventtickets'
$State = Join-Path $App 'build\demo'
$Log   = Join-Path $State 'app.log'
$ErrLog = Join-Path $State 'app.err.log'
$Db    = 'eventtickets-pg'

function Say($m)  { Write-Host "> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "OK $m" -ForegroundColor Green }
function Fail($m) { Write-Host "ERROR $m" -ForegroundColor Red; exit 1 }

function Test-PortInUse($p) {
  return [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue)
}
function Get-HttpStatus($url) {
  try { return (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).StatusCode } catch { return 0 }
}
function Test-Docker { docker info *> $null; return ($LASTEXITCODE -eq 0) }

if (-not (Test-Path (Join-Path $App 'gradlew.bat'))) { Fail "Project not found at $App" }
New-Item -ItemType Directory -Force -Path $State | Out-Null

# 0. Reset: stop the app first (the database is deleted after Docker is up, below)
if ($Reset) { & (Join-Path $PSScriptRoot 'stop.ps1') | Out-Null }

# Already running?
$portFile = Join-Path $State 'port'
if (-not $Reset -and (Test-Path $portFile)) {
  $running = (Get-Content $portFile -Raw).Trim()
  if ((Get-HttpStatus "http://localhost:$running/") -eq 200) {
    Ok "Already running: http://localhost:$running/"
    if ($Open) { Start-Process "http://localhost:$running/" }
    exit 0
  }
}

# 1. Docker
if (-not (Test-Docker)) {
  Say 'Docker is not running, opening Docker Desktop...'
  $dockerExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
  if (Test-Path $dockerExe) { Start-Process $dockerExe } else { Fail 'Docker Desktop not found. Install it or start it manually.' }
  for ($i = 0; $i -lt 90; $i++) { if (Test-Docker) { break }; Start-Sleep -Seconds 2 }
  if (-not (Test-Docker)) { Fail 'Docker did not start within 3 minutes.' }
}
Ok 'Docker is running'

if ($Reset) {
  docker rm -f $Db *> $null
  if ($LASTEXITCODE -eq 0) { Say "Deleted database container $Db (data reset)" }
}

# 2. Database (create the container the first time)
$exists = (docker ps -a --format '{{.Names}}') -contains $Db
if ($exists) {
  docker start $Db | Out-Null
} else {
  Say "Creating database container $Db on port 5433..."
  docker run -d --name $Db -e POSTGRES_DB=eventtickets -e POSTGRES_USER=eventtickets `
    -e POSTGRES_PASSWORD=eventtickets -p 5433:5432 postgres:17 | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail 'Could not create the database container (is port 5433 free?).' }
}
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
  docker exec $Db pg_isready -U eventtickets -q *> $null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Seconds 1
}
if (-not $ready) { Fail 'PostgreSQL did not become ready.' }
Ok 'PostgreSQL ready on localhost:5433'

# 3. Free port (8080/8081 are often used by other projects)
if ($Port -gt 0) {
  if (Test-PortInUse $Port) { Fail "Port $Port is already in use." }
  $use = $Port
} else {
  $use = $null
  foreach ($p in 8090, 8091, 8095, 9090, 9095) { if (-not (Test-PortInUse $p)) { $use = $p; break } }
  if (-not $use) { Fail 'No free port found (tried 8090 8091 8095 9090 9095).' }
}

# 4. Start the app in the background
Say "Starting the app on port $use (log: $Log)..."
$env:SERVER_PORT = "$use"
$env:DB_URL = 'jdbc:postgresql://localhost:5433/eventtickets'
if (-not $env:JWT_SECRET) { $env:JWT_SECRET = 'local-dev-secret-please-change-0123456789abcdef' }
Remove-Item $Log, $ErrLog -ErrorAction SilentlyContinue
$proc = Start-Process -FilePath (Join-Path $App 'gradlew.bat') -ArgumentList 'bootRun', '--quiet' `
  -WorkingDirectory $App -RedirectStandardOutput $Log -RedirectStandardError $ErrLog -WindowStyle Hidden -PassThru
Set-Content -Path (Join-Path $State 'gradle.pid') -Value $proc.Id
Set-Content -Path $portFile -Value $use

$started = $false
for ($i = 0; $i -lt 240; $i++) {
  if ((Test-Path $Log) -and (Select-String -Path $Log -Pattern 'Started EventTicketsApplication' -Quiet)) { $started = $true; break }
  $failed = $false
  foreach ($f in $Log, $ErrLog) {
    if ((Test-Path $f) -and (Select-String -Path $f -Pattern 'APPLICATION FAILED TO START', 'BUILD FAILED', 'FAILURE:' -Quiet)) { $failed = $true }
  }
  if ($failed) {
    Get-Content $Log, $ErrLog -ErrorAction SilentlyContinue | Select-String -Pattern 'Description:|Reason:|What went wrong' -Context 0, 4 | Select-Object -First 3
    Remove-Item $portFile -ErrorAction SilentlyContinue
    Fail "The app failed to start. Logs: $Log and $ErrLog"
  }
  Start-Sleep -Seconds 1
}
if (-not $started) { Fail "The app did not start within 4 minutes. Log: $Log" }

# 5. Check the demo page
$code = Get-HttpStatus "http://localhost:$use/"
if ($code -ne 200) { Fail "App started but the demo page returned HTTP $code." }
Ok 'App running'
Write-Host ''
Write-Host "  Demo page : http://localhost:$use/"
Write-Host "  Swagger   : http://localhost:$use/swagger-ui.html"
Write-Host '  Users     : admin/admin123 - alice/user123 - dara/user123'
Write-Host '  Stop      : demo-stop.cmd  (or stop.ps1 -Db to also stop PostgreSQL)'
if ($Open) { Start-Process "http://localhost:$use/" }
exit 0
