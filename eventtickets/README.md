# Event Tickets API

Homework for *Backend Development with Spring Boot* (slide 23).
Spring Boot 4.1 · Java 21 · Gradle (Groovy) · WAR · PostgreSQL · JPA · Flyway · JWT (HS256).

## Business rules

| # | Rule | Where | Result |
|---|------|-------|--------|
| 1 | No overbooking | `Event.reserveSeats`, row lock in `EventRepository.findByIdForUpdate` | 409 |
| 2 | Seats stay correct | `Event.reserveSeats` / `Event.releaseSeats`, double cancel blocked | — |
| 3 | 1–4 tickets per booking | `@Min(1) @Max(4)` on `CreateBookingRequest`, DB `CHECK` | 400 |
| 4 | Price from the server | `Booking.create` uses `event.price × quantity`; the request has no price field | — |
| 5 | No booking a cancelled event | `Event.reserveSeats` | 409 |
| 6 | Only your own bookings | `BookingService.findAccessible` (ADMIN may see all) | 403 |

Rule 1 also holds under concurrency: the event row is locked with `SELECT ... FOR UPDATE`
while seats are reserved. `ConcurrentBookingTest` fires 20 parallel bookings at a 5-seat event
and checks that exactly 5 succeed.

## Run

```bash
docker compose up -d                                   # PostgreSQL on :5432
export JWT_SECRET='change-me-to-a-random-32-byte-plus-secret'
./gradlew bootRun
```

Flyway creates the tables and seeds:

| User | Password | Role |
|------|----------|------|
| admin | admin123 | ADMIN |
| alice | user123 | USER |
| bob | user123 | USER |

Events: `1` Angkor Jazz Night (100 seats, 25.00), `2` Phnom Penh Tech Summit (5 seats, 40.00),
`3` Water Festival Concert (CANCELLED).

Tests use H2 in PostgreSQL mode, so they need neither Docker nor a secret: `./gradlew test`.

Build: `./gradlew bootWar` → `build/libs/eventtickets-0.0.1-SNAPSHOT.war`. Run it with
`java -jar`, or drop it into an external Tomcat 11 `webapps/`.

## Demo page

Open http://localhost:8080/ (the app serves `src/main/resources/static/index.html`).
One card per business rule; click **Run** on each step in order, or **Run all steps**. Each step logs in
as the right user (alice, bob or admin) automatically, shows the full HTTP request and response, and marks
the result ✓ or ✗ against the expected status. Every rule creates its own event first, so the demo works on
any data. Open `/#selftest` to run every step automatically.

If port 8080 is taken, start the app with `SERVER_PORT=8090` and open http://localhost:8090/.

## Swagger UI

Open http://localhost:8080/swagger-ui.html. Call `POST /api/auth/login`, copy `accessToken`,
click **Authorize** and paste it (without `Bearer `). The spec is at `/v3/api-docs`.

## Endpoints

| Method | Path | Role |
|--------|------|------|
| POST | `/api/auth/login` | public |
| GET | `/api/events?status=ACTIVE&page=0&size=20&sort=price,desc` | USER, ADMIN |
| GET | `/api/events/{id}` | USER, ADMIN |
| POST | `/api/events` | ADMIN |
| PUT | `/api/events/{id}` | ADMIN (cannot shrink below booked seats → 409) |
| POST | `/api/events/{id}/cancel` | ADMIN |
| POST | `/api/bookings` | USER, ADMIN |
| GET | `/api/bookings` | own bookings; ADMIN sees all |
| GET | `/api/bookings/{id}` | owner or ADMIN, else 403 |
| POST | `/api/bookings/{id}/cancel` | owner or ADMIN, else 403 |

Every error is an RFC 9457 `ProblemDetail` body (400, 401, 403, 404, 409, 500).

## curl

```bash
login() { curl -s localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d "{\"username\":\"$1\",\"password\":\"$2\"}" | sed -E 's/.*"accessToken":"([^"]+)".*/\1/'; }
ALICE=$(login alice user123); BOB=$(login bob user123); ADMIN=$(login admin admin123)

# List events
curl -s localhost:8080/api/events -H "Authorization: Bearer $ALICE"

# Book 3 tickets: total is 75.00 even if the client sends a price
curl -s localhost:8080/api/bookings -H "Authorization: Bearer $ALICE" \
  -H 'Content-Type: application/json' -d '{"eventId":1,"quantity":3,"totalAmount":0.01}'

# Rule 3: 5 tickets -> 400
curl -s localhost:8080/api/bookings -H "Authorization: Bearer $ALICE" \
  -H 'Content-Type: application/json' -d '{"eventId":1,"quantity":5}'

# Rule 1: event 2 has 5 seats; 4 + 2 -> second is 409
curl -s localhost:8080/api/bookings -H "Authorization: Bearer $ALICE" \
  -H 'Content-Type: application/json' -d '{"eventId":2,"quantity":4}'
curl -s localhost:8080/api/bookings -H "Authorization: Bearer $ALICE" \
  -H 'Content-Type: application/json' -d '{"eventId":2,"quantity":2}'

# Rule 5: cancelled event -> 409
curl -s localhost:8080/api/bookings -H "Authorization: Bearer $ALICE" \
  -H 'Content-Type: application/json' -d '{"eventId":3,"quantity":1}'

# Rule 6: Bob opens Alice's booking 1 -> 403
curl -s localhost:8080/api/bookings/1 -H "Authorization: Bearer $BOB"

# Rule 2: Alice cancels, seats come back
curl -s -X POST localhost:8080/api/bookings/1/cancel -H "Authorization: Bearer $ALICE"
curl -s localhost:8080/api/events/1 -H "Authorization: Bearer $ALICE"

# ADMIN creates an event (USER gets 403)
curl -s localhost:8080/api/events -H "Authorization: Bearer $ADMIN" -H 'Content-Type: application/json' \
  -d '{"name":"Khmer New Year Show","eventDate":"2027-04-14T18:00:00","venue":"Olympic Stadium","price":12.50,"totalSeats":300}'
```

## Layout

```
com.kosign.eventtickets
├── config/          SecurityConfig, OpenApiConfig, JwtProperties
├── controller/      AuthController, EventController, BookingController
├── service/         AuthService, EventService, BookingService (interfaces)
│   └── impl/        AuthServiceImpl, EventServiceImpl, BookingServiceImpl
├── repository/      UserRepository, EventRepository, BookingRepository
├── domain/entity/   BaseEntity (audit columns), AppUser, Event, Booking
│   └── enums/       Role, EventStatus, BookingStatus
├── dto/request/     LoginRequest, EventRequest, CreateBookingRequest
├── dto/response/    TokenResponse, EventResponse, BookingResponse
├── mapper/          EventMapper, BookingMapper (entity <-> DTO)
├── exception/       GlobalExceptionHandler, NotFoundException, ConflictException
├── security/        CurrentUser (caller read from the JWT)
└── util/            DateTimes (VARCHAR(14) date format)
```

Request path: `controller → service (interface) → service/impl → repository → database`.
Business rules live in the entities (`Event.reserveSeats`, `Booking.cancel`).

DB conventions: uppercase abbreviated columns, `VARCHAR(14)` datetimes (`YYYYMMDDHH24MISS`),
audit columns `REG_DTM / MOD_DTM / REG_ID / MOD_ID` filled by `BaseEntity`.
