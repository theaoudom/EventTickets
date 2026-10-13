# Event Tickets API

Homework for *Backend Development with Spring Boot* (KOSIGN): a ticket booking REST API with Spring Boot 4,
PostgreSQL, Flyway and JWT, implementing six business rules (no overbooking, correct seats, max 4 tickets,
server-side price, no booking a cancelled event, own bookings only).

| Path | What |
|---|---|
| [`eventtickets/`](eventtickets/) | The Spring Boot project. See its [README](eventtickets/README.md) for endpoints and curl examples |
| [`Event-Tickets-API-Explanation.pdf`](Event-Tickets-API-Explanation.pdf) | Full explanation: setup, architecture, request flow, security, demo script, mentor Q&A |
| [`.claude/skills/demo/`](.claude/skills/demo/) | `/demo` skill for Claude Code: starts PostgreSQL + the app and opens the demo page |

## Run

Requires Java 21 and Docker.

```bash
bash .claude/skills/demo/scripts/start.sh --open   # PostgreSQL (port 5433) + app, opens the demo page
bash .claude/skills/demo/scripts/stop.sh --db      # stop the app and the database
```

Logins: `admin/admin123` (ADMIN), `alice/user123` and `bob/user123` (USER).

Tests (no Docker needed): `cd eventtickets && ./gradlew test`
