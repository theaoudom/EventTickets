---
name: demo
description: Start, stop or reset the Event Tickets API demo in this project — opens Docker if needed, starts PostgreSQL (container eventtickets-pg, port 5433), runs the Spring Boot app on a free port, checks the demo page and prints its URL. Use when asked to start, run, open, restart, reset or stop the demo/app/project. Usage: /demo [start | stop | stop --db | restart | reset | status]
---

# Event Tickets demo

The app lives in `eventtickets/`. The demo page (`src/main/resources/static/index.html`: one tab per business rule with
steps to run, the request/response, and the rule's event with its seats and bookings) is served by the app itself at `/`
(not openable as a file), so the database and the app must both be running. Two scripts do all the work:

- `.claude/skills/demo/scripts/start.sh` — database → app → checks `GET /` returns 200 → prints the URLs.
  Picks the first free port of 8090, 8091, 8095, 9090, 9095 (8080/8081 are often taken by other KOSIGN projects).
  Safe to run twice: if the app is already up it just prints the URL. `PORT=8095` forces a port; `--open` opens the browser;
  `--reset` deletes the database container first so the data goes back to the 3 seed events and 3 users.
  `--database=auto|docker|local|h2` (default `auto`) chooses the database; see below.
- `.claude/skills/demo/scripts/stop.sh` — stops only this project's app (checks the process before killing). `--db` also stops PostgreSQL.
- **Windows:** `start.ps1` / `stop.ps1` do the same in PowerShell (the `.sh` scripts need macOS tools such as `lsof`
  and `open`). Same options as switches: `-Open`, `-Reset`, `-Port 8095`, and `-Db` for stop. Users without Claude
  Code can double-click `demo-start.cmd` / `demo-stop.cmd` in the repo root.

Run state (port, pid, log, chosen database in `mode`) is kept in `eventtickets/build/demo/`.

## Which database

`auto` uses the first that works, and the script prints which one it chose (tell the user):

1. **docker** — PostgreSQL in the `eventtickets-pg` container on port 5433. Opens Docker Desktop if it is installed but closed.
2. **local** — a PostgreSQL already installed on the PC, listening on port 5432 (`LOCAL_DB_PORT` / `-LocalDbPort` to change).
   Needs database and user `eventtickets` (password `eventtickets`, or set `DB_USERNAME` / `DB_PASSWORD`). If they are
   missing the script prints the two SQL lines to run once in pgAdmin or psql as the postgres user:
   `CREATE USER eventtickets WITH PASSWORD 'eventtickets';` and `CREATE DATABASE eventtickets OWNER eventtickets;`
   Never create them yourself with the user's postgres password unless the user gives it and asks you to.
3. **h2** — the built-in in-memory database (Spring profile `h2`). Needs only Java; same Flyway migrations and rules;
   data resets whenever the app restarts. Say so when it is chosen.

`reset` only deletes data in the Docker database; for `local` the script prints the SQL to reset it instead.

## Which scripts to use

Check the OS first: run `uname -s` (on Windows, Claude Code's shell is Git Bash and prints `MINGW…`/`MSYS…`;
`echo $OS` prints `Windows_NT`).

- **macOS / Linux:** `bash .claude/skills/demo/scripts/<name>.sh <options>`
- **Windows:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/skills/demo/scripts/<name>.ps1 <switches>`

## What to do

Pick the action from the argument (no argument → `start`):

| Argument | macOS / Linux | Windows (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File …`) |
|---|---|---|
| `start` (default) | `start.sh --open` | `start.ps1 -Open` |
| `stop` | `stop.sh` | `stop.ps1` |
| `stop --db` | `stop.sh --db` | `stop.ps1 -Db` |
| `restart` | `stop.sh`, then `start.sh --open` | `stop.ps1`, then `start.ps1 -Open` |
| `reset` | `start.sh --reset --open` | `start.ps1 -Reset -Open` |
| `h2` (no database needed) | `start.sh --database=h2 --open` | `start.ps1 -Database h2 -Open` |
| `status` | `cat eventtickets/build/demo/port`, then `curl -s -o /dev/null -w '%{http_code}' http://localhost:<port>/`; `docker ps --filter name=eventtickets-pg` | same commands (they work in Git Bash) |

`reset` **deletes all bookings and events made since setup**; run it only when the user asked for `reset`.

Run the commands from the repo root (the folder that contains `eventtickets/`) with a timeout of at least 300000 ms — the first start downloads
the PostgreSQL image and compiles the app. Run the start script in the foreground: it returns as soon as the app is ready
and leaves the app running in the background.

## Report back

On success, give the user the demo URL and the logins in a few lines:

```
Demo running: http://localhost:<port>/
Logins: admin/admin123 · alice/user123 · dara/user123
Stop with /demo stop
```

## If it fails

The script prints the reason and the log path (`eventtickets/build/demo/app.log`). Read the log, then:

| Message | Fix |
|---|---|
| Docker did not start | Ask the user to open Docker Desktop, then run again |
| Port … already in use | Run again without `PORT`, or pick another port |
| `Connection to localhost:5433 refused` | `docker start eventtickets-pg`, then run again |
| `APPLICATION FAILED TO START` / compile error | Show the error from the log; fix the code, then `./gradlew test` before restarting |

Never kill processes that are not this project's app (other projects run on 8080/8081 on this machine), and never
`docker rm` the database container unless the user asks to reset the data.
