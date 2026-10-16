# Event Tickets API

Homework for *Backend Development with Spring Boot* (KOSIGN): a ticket booking REST API with Spring Boot 4,
PostgreSQL, Flyway and JWT, implementing six business rules (no overbooking, correct seats, max 4 tickets,
server-side price, no booking a cancelled event, own bookings only).

| Path | What |
|---|---|
| [`docs/`](docs/) | Project documents: [BRD](docs/BRD.md), [PRD](docs/PRD.md), [ERD](docs/ERD.md), [API Spec](docs/API-SPEC.md) |
| [`eventtickets/`](eventtickets/) | The Spring Boot project. See its [README](eventtickets/README.md) for endpoints and curl examples |
| [`Event-Tickets-API-Explanation.pdf`](Event-Tickets-API-Explanation.pdf) | Full explanation: setup, architecture, request flow, security, demo script, mentor Q&A |
| [`.claude/skills/demo/`](.claude/skills/demo/) | `/demo` skill for Claude Code (Mac and Windows): starts PostgreSQL + the app and opens the demo page |

## Run

Requires **Java 21** and **PostgreSQL**, either through **Docker Desktop** (a container on port 5433, created
automatically) or a **PostgreSQL installed on the PC** (found automatically on its port). The start output says which
one it used and prints the DBeaver connection settings.
The first start downloads Gradle (and PostgreSQL for Docker), so it takes a few minutes.

Using an installed PostgreSQL? Create the project database once (pgAdmin Query Tool, as the postgres user):

```sql
CREATE USER eventtickets WITH PASSWORD 'eventtickets';
CREATE DATABASE eventtickets OWNER eventtickets;
```

| | Start (opens the demo page) | Stop |
|---|---|---|
| **Claude Code** (Mac or Windows) | `/demo` · `/demo reset` for clean seed data | `/demo stop` |
| **Windows** | double-click **`demo-start.cmd`** (`demo-start.cmd reset` for clean seed data) | double-click **`demo-stop.cmd`** |
| **Mac / Linux** | `bash .claude/skills/demo/scripts/start.sh --open` | `bash .claude/skills/demo/scripts/stop.sh --db` |

Logins: `admin/admin123` (ADMIN), `alice/user123` and `dara/user123` (USER).

Tests (no Docker needed): `cd eventtickets && ./gradlew test`
