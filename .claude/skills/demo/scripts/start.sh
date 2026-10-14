#!/usr/bin/env bash
# Starts the Event Tickets demo: Docker -> PostgreSQL (port 5433) -> Spring Boot app -> prints the demo URL.
# Usage: start.sh [--open] [--reset]    PORT=8095 start.sh  (force a port)
#   --reset  deletes the database container first, so Flyway recreates the tables and the original seed data
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
APP="$ROOT/eventtickets"
STATE="$APP/build/demo"
LOG="$STATE/app.log"
DB=eventtickets-pg
OPEN=false
RESET=false
for arg in "$@"; do
  case "$arg" in
    --open) OPEN=true ;;
    --reset) RESET=true ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

[[ -x "$APP/gradlew" ]] || fail "Project not found at $APP"
mkdir -p "$STATE"

# 0. Reset: stop the app first (the database is deleted after Docker is up, below)
$RESET && bash "$SKILL_DIR/scripts/stop.sh" >/dev/null

# Already running?
if [[ -f "$STATE/port" ]]; then
  port=$(cat "$STATE/port")
  if curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/" 2>/dev/null | grep -q 200 \
     && lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | grep -q java; then
    ok "Already running: http://localhost:$port/"
    $OPEN && open "http://localhost:$port/"
    exit 0
  fi
fi

# 1. Docker
if ! docker info >/dev/null 2>&1; then
  say "Docker is not running, opening Docker Desktop..."
  open -a Docker || fail "Could not open Docker Desktop. Start it manually."
  for _ in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 2; done
  docker info >/dev/null 2>&1 || fail "Docker did not start within 3 minutes."
fi
ok "Docker is running"

if $RESET; then
  docker rm -f "$DB" >/dev/null 2>&1 && say "Deleted database container $DB (data reset)"
fi

# 2. Database (create the container the first time)
if docker ps -a --format '{{.Names}}' | grep -qx "$DB"; then
  docker start "$DB" >/dev/null
else
  say "Creating database container $DB on port 5433..."
  docker run -d --name "$DB" -e POSTGRES_DB=eventtickets -e POSTGRES_USER=eventtickets \
    -e POSTGRES_PASSWORD=eventtickets -p 5433:5432 postgres:17 >/dev/null
fi
for _ in $(seq 1 30); do docker exec "$DB" pg_isready -U eventtickets -q 2>/dev/null && break; sleep 1; done
docker exec "$DB" pg_isready -U eventtickets -q || fail "PostgreSQL did not become ready."
ok "PostgreSQL ready on localhost:5433"

# 3. Free port (8080/8081 are often used by other projects)
pick_port() {
  for p in ${PORT:-} 8090 8091 8095 9090 9095; do
    lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 || { echo "$p"; return; }
  done
  return 1
}
port=$(pick_port) || fail "No free port found (tried 8090 8091 8095 9090 9095)."
[[ -n "${PORT:-}" && "$port" != "$PORT" ]] && fail "Port $PORT is already in use."

# 4. Start the app in the background
say "Starting the app on port $port (log: $LOG)..."
cd "$APP"
SERVER_PORT="$port" \
DB_URL="jdbc:postgresql://localhost:5433/eventtickets" \
JWT_SECRET="${JWT_SECRET:-local-dev-secret-please-change-0123456789abcdef}" \
  nohup ./gradlew bootRun --quiet >"$LOG" 2>&1 &
echo $! >"$STATE/gradle.pid"
echo "$port" >"$STATE/port"

for _ in $(seq 1 180); do
  grep -q "Started EventTicketsApplication" "$LOG" 2>/dev/null && break
  if grep -qE "APPLICATION FAILED TO START|BUILD FAILED|FAILURE:" "$LOG" 2>/dev/null; then
    grep -A6 -E "APPLICATION FAILED TO START|What went wrong" "$LOG" | head -12 >&2
    rm -f "$STATE/port"
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
echo "  Users     : admin/admin123 · alice/user123 · bob/user123"
echo "  Stop      : .claude/skills/demo/scripts/stop.sh   (add --db to also stop PostgreSQL)"
$OPEN && open "http://localhost:$port/"
exit 0
