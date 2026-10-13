#!/usr/bin/env bash
# Stops the Event Tickets demo app. Usage: stop.sh [--db]   (--db also stops the PostgreSQL container)
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
STATE="$ROOT/eventtickets/build/demo"

stopped=false
if [[ -f "$STATE/port" ]]; then
  port=$(cat "$STATE/port")
  # Only kill the Java process on that port if it is this project's app
  for pid in $(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null); do
    if ps -p "$pid" -o command= | grep -q "eventtickets"; then
      kill "$pid" && stopped=true
    else
      echo "Port $port is used by another program (pid $pid); not touching it." >&2
    fi
  done
  rm -f "$STATE/port"
fi
if [[ -f "$STATE/gradle.pid" ]]; then
  kill "$(cat "$STATE/gradle.pid")" 2>/dev/null || true
  rm -f "$STATE/gradle.pid"
fi
$stopped && echo "✓ App stopped" || echo "App was not running"

if [[ "${1:-}" == "--db" ]]; then
  docker stop eventtickets-pg >/dev/null 2>&1 && echo "✓ PostgreSQL stopped" || echo "PostgreSQL was not running"
fi
