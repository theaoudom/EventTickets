#!/usr/bin/env bash
# Starts the Event Tickets demo: database -> Spring Boot app -> prints the demo URL.
# Usage: start.sh [--open] [--reset] [--database=auto|docker|local]     PORT=8095 start.sh  (force a port)
#   --database=auto (default) picks the first that works:
#       docker  PostgreSQL in a Docker container on port 5433 (opens Docker Desktop if it is installed but closed)
#       local   a PostgreSQL already installed on this PC (found on whatever port it runs; LOCAL_DB_PORT to force one),
#               database/user "eventtickets"
#   --reset  docker: deletes the container so Flyway recreates the tables and seed data
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
APP="$ROOT/eventtickets"
STATE="$APP/build/demo"
LOG="$STATE/app.log"
DB=eventtickets-pg
LOCAL_DB_PORT_GIVEN=${LOCAL_DB_PORT:+yes}
LOCAL_DB_PORT="${LOCAL_DB_PORT:-5432}"
OPEN=false
RESET=false
DATABASE=auto
for arg in "$@"; do
  case "$arg" in
    --open) OPEN=true ;;
    --reset) RESET=true ;;
    --database=auto|--database=docker|--database=local) DATABASE="${arg#--database=}" ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }
listening() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

[[ -x "$APP/gradlew" ]] || fail "Project not found at $APP"
mkdir -p "$STATE"

# 0. Reset: stop the app first (the data itself is reset below, once the database is chosen)
$RESET && bash "$SKILL_DIR/scripts/stop.sh" >/dev/null

# Already running?
if ! $RESET && [[ -f "$STATE/port" ]]; then
  port=$(cat "$STATE/port")
  if curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/" 2>/dev/null | grep -q 200 \
     && lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | grep -q java; then
    ok "Already running: http://localhost:$port/ ($(cat "$STATE/mode" 2>/dev/null || echo docker))"
    $OPEN && open "http://localhost:$port/"
    exit 0
  fi
fi

# 1. Choose the database
docker_ready() { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }
docker_installed() { command -v docker >/dev/null 2>&1 || [[ -d /Applications/Docker.app ]]; }
try_docker() {
  docker_ready && return 0
  docker_installed || return 1
  say "Docker is not running, opening Docker Desktop..."
  open -a Docker >/dev/null 2>&1 || return 1
  for _ in $(seq 1 90); do docker_ready && return 0; sleep 2; done
  return 1
}

# Port of a PostgreSQL server running on this machine: LOCAL_DB_PORT if something listens there, else found by
# process name on any port (only when LOCAL_DB_PORT was not given)
local_pg_port() {
  if listening "$LOCAL_DB_PORT"; then echo "$LOCAL_DB_PORT"; return 0; fi
  [[ -n "$LOCAL_DB_PORT_GIVEN" ]] && return 1
  local p
  p=$(lsof -nP -iTCP -sTCP:LISTEN -c postgres 2>/dev/null | awk 'NR>1 {n=split($9, a, ":"); print a[n]}' | sort -n | head -1)
  [[ -n "$p" ]] && { echo "$p"; return 0; }
  return 1
}

MODE=""
case "$DATABASE" in
  docker) try_docker && MODE=docker || fail "Docker is not available (use --database=local)." ;;
  local)  if p=$(local_pg_port); then LOCAL_DB_PORT=$p; MODE=local; else fail "No running PostgreSQL found on this machine."; fi ;;
  auto)
    if try_docker; then MODE=docker
    elif p=$(local_pg_port); then LOCAL_DB_PORT=$p; MODE=local; warn "Docker not available - using the PostgreSQL installed on this PC (port $LOCAL_DB_PORT)"
    else fail "No PostgreSQL found: start Docker Desktop, or install/start PostgreSQL on this machine, then run this again."
    fi ;;
esac
echo "$MODE" >"$STATE/mode"
echo "$LOCAL_DB_PORT" >"$STATE/local_db_port"

# 2. Prepare the database
DB_ENV=()
case "$MODE" in
  docker)
    ok "Docker is running"
    if $RESET; then
      docker rm -f "$DB" >/dev/null 2>&1 && say "Deleted database container $DB (data reset)"
    fi
    if docker ps -a --format '{{.Names}}' | grep -qx "$DB"; then
      docker start "$DB" >/dev/null
    else
      say "Creating database container $DB on port 5433..."
      docker run -d --name "$DB" -e POSTGRES_DB=eventtickets -e POSTGRES_USER=eventtickets \
        -e POSTGRES_PASSWORD=eventtickets -p 5433:5432 postgres:17 >/dev/null
    fi
    for _ in $(seq 1 30); do docker exec "$DB" pg_isready -U eventtickets -q 2>/dev/null && break; sleep 1; done
    docker exec "$DB" pg_isready -U eventtickets -q || fail "PostgreSQL did not become ready."
    ok "Database: PostgreSQL in Docker (localhost:5433)"
    DB_ENV=(DB_URL="jdbc:postgresql://localhost:5433/eventtickets")
    ;;
  local)
    $RESET && warn "--reset does not touch a local PostgreSQL. To reset it, run in pgAdmin/psql on database eventtickets: DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
    ok "Database: local PostgreSQL (localhost:$LOCAL_DB_PORT, database eventtickets)"
    DB_ENV=(DB_URL="jdbc:postgresql://localhost:$LOCAL_DB_PORT/eventtickets"
            DB_USERNAME="${DB_USERNAME:-eventtickets}" DB_PASSWORD="${DB_PASSWORD:-eventtickets}")
    ;;
esac

# 3. Free port (8080/8081 are often used by other projects)
pick_port() {
  for p in ${PORT:-} 8090 8091 8095 9090 9095; do
    listening "$p" || { echo "$p"; return; }
  done
  return 1
}
port=$(pick_port) || fail "No free port found (tried 8090 8091 8095 9090 9095)."
[[ -n "${PORT:-}" && "$port" != "$PORT" ]] && fail "Port $PORT is already in use."

# 4. Start the app in the background
say "Starting the app on port $port (log: $LOG)..."
cd "$APP"
env SERVER_PORT="$port" "${DB_ENV[@]}" \
  JWT_SECRET="${JWT_SECRET:-local-dev-secret-please-change-0123456789abcdef}" \
  nohup ./gradlew bootRun --quiet >"$LOG" 2>&1 &
echo $! >"$STATE/gradle.pid"
echo "$port" >"$STATE/port"

local_db_help() {
  cat >&2 <<'EOF'

  The local PostgreSQL needs the project's database once. In pgAdmin (Query Tool on "postgres")
  or psql as the postgres user, run:

      CREATE USER eventtickets WITH PASSWORD 'eventtickets';
      CREATE DATABASE eventtickets OWNER eventtickets;

  Then start again. (Or use other credentials: DB_USERNAME=... DB_PASSWORD=... start.sh)
EOF
}

for _ in $(seq 1 180); do
  grep -q "Started EventTicketsApplication" "$LOG" 2>/dev/null && break
  if grep -qE "APPLICATION FAILED TO START|BUILD FAILED|FAILURE:" "$LOG" 2>/dev/null; then
    rm -f "$STATE/port"
    if [[ "$MODE" == local ]] && grep -qE 'password authentication failed|does not exist' "$LOG"; then
      local_db_help
    else
      grep -A6 -E "APPLICATION FAILED TO START|What went wrong" "$LOG" | head -12 >&2
    fi
    fail "The app failed to start. Full log: $LOG"
  fi
  sleep 1
done
grep -q "Started EventTicketsApplication" "$LOG" || fail "The app did not start within 3 minutes. Log: $LOG"

# 5. Check the demo page
code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/")
[[ "$code" == 200 ]] || fail "App started but the demo page returned HTTP $code."
ok "App running"
echo
echo "  Demo page : http://localhost:$port/"
echo "  Swagger   : http://localhost:$port/swagger-ui.html"
echo "  Database  : $MODE"
case "$MODE" in
  docker) echo "  DBeaver   : PostgreSQL · host localhost · port 5433 · database eventtickets · user eventtickets · password eventtickets" ;;
  local)  echo "  DBeaver   : PostgreSQL · host localhost · port $LOCAL_DB_PORT · database eventtickets · user ${DB_USERNAME:-eventtickets} · password ${DB_PASSWORD:-eventtickets}" ;;
esac
echo "  Users     : admin/admin123 · alice/user123 · dara/user123"
echo "  Stop      : .claude/skills/demo/scripts/stop.sh   (add --db to also stop the Docker database)"
$OPEN && open "http://localhost:$port/"
exit 0
