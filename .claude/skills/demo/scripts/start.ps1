# Windows version of start.sh: database -> Spring Boot app -> prints the demo URL.
# Usage (from the repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .claude\skills\demo\scripts\start.ps1 [-Open] [-Reset] [-Port 8095] [-Database auto|docker|local]
#   -Database auto (default) picks the first that works:
#       docker  PostgreSQL in a Docker container on port 5433 (opens Docker Desktop if it is installed but closed)
#       local   a PostgreSQL already installed on this PC (found on whatever port it runs; -LocalDbPort to force one),
#               database/user "eventtickets"
#   -Reset  docker: deletes the container so Flyway recreates the tables and seed data
# Keep this file plain ASCII: Windows PowerShell 5.1 misreads UTF-8 files without a BOM.
param(
  [switch]$Open,
  [switch]$Reset,
  [int]$Port = 0,
  [ValidateSet('auto', 'docker', 'local')][string]$Database = 'auto',
  [int]$LocalDbPort = 5432
)

$ErrorActionPreference = 'Continue'
$Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$App    = Join-Path $Root 'eventtickets'
$State  = Join-Path $App 'build\demo'
$Log    = Join-Path $State 'app.log'
$ErrLog = Join-Path $State 'app.err.log'
$Db     = 'eventtickets-pg'

function Say($m)  { Write-Host "> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "OK $m" -ForegroundColor Green }
function Warn($m) { Write-Host "! $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "ERROR $m" -ForegroundColor Red; exit 1 }

function Test-PortInUse($p) {
  return [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue)
}
function Get-HttpStatus($url) {
  try { return (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).StatusCode } catch { return 0 }
}
function Test-DockerReady {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return $false }
  docker info *> $null
  return ($LASTEXITCODE -eq 0)
}
# Port of a PostgreSQL server running on this PC, found by its process name (any port), or $null
function Find-LocalPostgresPort {
  $listening = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalAddress -in @('0.0.0.0', '::', '127.0.0.1', '::1') } | Sort-Object LocalPort
  foreach ($c in $listening) {
    $p = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
    if ($p -and $p.ProcessName -match '^postgres') { return [int]$c.LocalPort }
  }
  return $null
}
function Start-DockerIfInstalled {
  if (Test-DockerReady) { return $true }
  $dockerExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
  if (-not (Test-Path $dockerExe)) { return $false }
  Say 'Docker is not running, opening Docker Desktop...'
  Start-Process $dockerExe
  for ($i = 0; $i -lt 90; $i++) { if (Test-DockerReady) { return $true }; Start-Sleep -Seconds 2 }
  return $false
}

if (-not (Test-Path (Join-Path $App 'gradlew.bat'))) { Fail "Project not found at $App" }
New-Item -ItemType Directory -Force -Path $State | Out-Null

# 0. Reset: stop the app first (the data itself is reset below, once the database is chosen)
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

# 1. Choose the database
$mode = $null
$portGiven = $PSBoundParameters.ContainsKey('LocalDbPort')
function Resolve-LocalPostgres {
  if ($portGiven) { if (Test-PortInUse $LocalDbPort) { return $LocalDbPort } else { return $null } }
  if (Test-PortInUse $LocalDbPort) { return $LocalDbPort }
  return Find-LocalPostgresPort
}
function Warn-StoppedPostgres {
  $stopped = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Running' }
  foreach ($svc in $stopped) {
    Warn "PostgreSQL is installed but its service '$($svc.Name)' is stopped. Start it: Win+R, services.msc, right-click it, Start - then run this again."
  }
}
switch ($Database) {
  'docker' { if (Start-DockerIfInstalled) { $mode = 'docker' } else { Fail 'Docker is not available (use -Database local).' } }
  'local'  {
    $found = Resolve-LocalPostgres
    if ($found) { $LocalDbPort = $found; $mode = 'local' } else { Warn-StoppedPostgres; Fail 'No running PostgreSQL found on this PC.' }
  }
  default {
    if (Start-DockerIfInstalled) { $mode = 'docker' }
    else {
      $found = Resolve-LocalPostgres
      if ($found) { $LocalDbPort = $found; $mode = 'local'; Warn "Docker not available - using the PostgreSQL installed on this PC (port $LocalDbPort)" }
      else {
        Warn-StoppedPostgres
        Fail 'No PostgreSQL found: start Docker Desktop, or install/start PostgreSQL on this PC, then run this again.'
      }
    }
  }
}
Set-Content -Path (Join-Path $State 'mode') -Value $mode
Set-Content -Path (Join-Path $State 'local_db_port') -Value $LocalDbPort

# 2. Prepare the database and the settings for the app
if ($mode -eq 'docker') {
  Ok 'Docker is running'
  if ($Reset) {
    docker rm -f $Db *> $null
    if ($LASTEXITCODE -eq 0) { Say "Deleted database container $Db (data reset)" }
  }
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
  Ok 'Database: PostgreSQL in Docker (localhost:5433)'
  $env:DB_URL = 'jdbc:postgresql://localhost:5433/eventtickets'
}
elseif ($mode -eq 'local') {
  if ($Reset) { Warn '-Reset does not touch a local PostgreSQL. To reset it, run in pgAdmin on database eventtickets: DROP SCHEMA public CASCADE; CREATE SCHEMA public;' }
  Ok "Database: local PostgreSQL (localhost:$LocalDbPort, database eventtickets)"
  $env:DB_URL = "jdbc:postgresql://localhost:$LocalDbPort/eventtickets"
  if (-not $env:DB_USERNAME) { $env:DB_USERNAME = 'eventtickets' }
  if (-not $env:DB_PASSWORD) { $env:DB_PASSWORD = 'eventtickets' }
}

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
    Remove-Item $portFile -ErrorAction SilentlyContinue
    $dbProblem = ($mode -eq 'local') -and (Select-String -Path $Log -Pattern 'password authentication failed', 'does not exist' -Quiet)
    if ($dbProblem) {
      Write-Host ''
      Write-Host '  The local PostgreSQL needs the project database once. In pgAdmin, open the Query Tool on'
      Write-Host '  the "postgres" database (as the postgres user) and run:'
      Write-Host ''
      Write-Host "      CREATE USER eventtickets WITH PASSWORD 'eventtickets';" -ForegroundColor Yellow
      Write-Host '      CREATE DATABASE eventtickets OWNER eventtickets;' -ForegroundColor Yellow
      Write-Host ''
      Write-Host '  Then start again.'
    } else {
      Get-Content $Log, $ErrLog -ErrorAction SilentlyContinue | Select-String -Pattern 'Description:|Reason:|What went wrong' -Context 0, 4 | Select-Object -First 3
    }
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
Write-Host "  Database  : $mode"
if ($mode -eq 'docker') { Write-Host '  DBeaver   : PostgreSQL - host localhost - port 5433 - database eventtickets - user eventtickets - password eventtickets' }
elseif ($mode -eq 'local') { Write-Host "  DBeaver   : PostgreSQL - host localhost - port $LocalDbPort - database eventtickets - user $($env:DB_USERNAME) - password $($env:DB_PASSWORD)" }
Write-Host '  Users     : admin/admin123 - alice/user123 - dara/user123'
Write-Host '  Stop      : demo-stop.cmd  (or stop.ps1 -Db to also stop the Docker database)'
if ($Open) { Start-Process "http://localhost:$use/" }
exit 0
