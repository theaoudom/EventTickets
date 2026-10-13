---
name: demo
description: Start or stop the Event Tickets API demo in this project — opens Docker if needed, starts PostgreSQL (container eventtickets-pg, port 5433), runs the Spring Boot app on a free port, checks the demo page and prints its URL. Use when asked to start, run, open, restart or stop the demo/app/project. Usage: /demo [start | stop | stop --db | restart | status]
---

# Event Tickets demo

The app lives in `eventtickets/`. The demo page is served by the app itself at `/` (not openable as a file), so the
database and the app must both be running. Two scripts do all the work:

- `.claude/skills/demo/scripts/start.sh` — Docker → PostgreSQL → app → checks `GET /` returns 200 → prints the URLs.
  Picks the first free port of 8090, 8091, 8095, 9090, 9095 (8080/8081 are often taken by other KOSIGN projects).
  Safe to run twice: if the app is already up it just prints the URL. `PORT=8095` forces a port; `--open` opens the browser.
- `.claude/skills/demo/scripts/stop.sh` — stops only this project's app (checks the process before killing). `--db` also stops PostgreSQL.

Run state (port, pid, log) is kept in `eventtickets/build/demo/`.

## What to do

Pick the action from the argument (no argument → `start`):

| Argument | Run |
|---|---|
| `start` (default) | `bash .claude/skills/demo/scripts/start.sh --open` |
| `stop` | `bash .claude/skills/demo/scripts/stop.sh` |
| `stop --db` | `bash .claude/skills/demo/scripts/stop.sh --db` |
| `restart` | `stop.sh`, then `start.sh --open` |
| `status` | `cat eventtickets/build/demo/port` and `curl -s -o /dev/null -w '%{http_code}' http://localhost:<port>/`; `docker ps --filter name=eventtickets-pg` |

Run the commands from the project root (`Homework/`) with a timeout of at least 300000 ms — the first start downloads
the PostgreSQL image and compiles the app. Run `start.sh` in the foreground: it returns as soon as the app is ready
and leaves the app running in the background.

## Report back

On success, give the user the demo URL and the logins in a few lines:

```
Demo running: http://localhost:<port>/
Logins: admin/admin123 · alice/user123 · bob/user123
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
