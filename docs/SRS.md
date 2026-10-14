# SRS – Software Requirements Specification

**Project:** Event Tickets API · **Version:** 1.0 · **Date:** October 2026 · **Owner:** Thea Oudom
**Based on:** [BRD](BRD.md), [PRD](PRD.md) · **Source:** course homework, slide 22

> The SRS explains **how** the system is built: technology, architecture, security and quality requirements.

---

## 1. Technology

| Item | Choice | Why |
|---|---|---|
| Language | Java 21 (LTS) | Required; long-term support |
| Framework | Spring Boot 4.1 | Required |
| Build | Gradle (Groovy DSL) | Required |
| Packaging | WAR | Required; also runs with `java -jar` |
| Database | PostgreSQL 17 | Required |
| ORM | Spring Data JPA / Hibernate | Standard; less SQL to write |
| Schema migrations | Flyway | Versioned, repeatable SQL |
| Security | Spring Security + OAuth2 Resource Server (JWT, HS256) | Stateless login for web and mobile |
| Validation | Jakarta Bean Validation | Input rules declared on DTOs |
| API docs | springdoc-openapi (Swagger UI) | Generated from the code |
| Tests | JUnit 5, MockMvc, H2 (PostgreSQL mode) | Tests run without Docker |

## 2. Architecture

Layered architecture, each layer calls only the one below it:

```
Client (web / mobile / demo page)
   │  HTTP + JSON, Authorization: Bearer <JWT>
   ▼
Security filter chain ── checks the token and the role ──► 401 / 403
   ▼
Controller ── validates input (@Valid) ──► 400
   ▼
Service (interface + impl) ── transaction, ownership check, business rules ──► 403 / 404 / 409
   ▼
Repository (Spring Data JPA)
   ▼
PostgreSQL (schema created by Flyway)
```

### Package structure

```
com.kosign.eventtickets
├── config/          SecurityConfig, OpenApiConfig, JwtProperties
├── controller/      AuthController, EventController, BookingController
├── service/         AuthService, EventService, BookingService      (interfaces)
│   └── impl/        AuthServiceImpl, EventServiceImpl, BookingServiceImpl
├── repository/      UserRepository, EventRepository, BookingRepository
├── domain/entity/   BaseEntity, AppUser, Event, Booking
│   └── enums/       Role, EventStatus, BookingStatus
├── dto/request/     LoginRequest, EventRequest, CreateBookingRequest
├── dto/response/    TokenResponse, EventResponse, BookingResponse
├── mapper/          EventMapper, BookingMapper
├── exception/       GlobalExceptionHandler, NotFoundException, ConflictException
├── security/        CurrentUser
└── util/            DateTimes
```

| Layer | Responsibility | Must not |
|---|---|---|
| Controller | HTTP: URL, input validation, status code | contain business logic or call repositories |
| Service | Use case, `@Transactional`, ownership checks | return entities to the controller |
| Entity | Business rules (`Event.reserveSeats()`, `Booking.cancel()`) | have public setters |
| Repository | Load and save data | contain business rules |
| Mapper | Entity ⇄ DTO conversion | — |

## 3. How each business rule is implemented

| Rule | Implementation | Code |
|---|---|---|
| BR-01 No overbooking | Check seats left; the event row is locked with `SELECT … FOR UPDATE` during booking, so concurrent bookings wait in line. DB `CHECK (AVL_SEAT >= 0)` as a safety net | `Event.reserveSeats()`, `EventRepository.findByIdForUpdate()` |
| BR-02 Seats correct | Booking subtracts seats, cancel adds them back; cancelling twice → 409 | `Event.releaseSeats()`, `Booking.cancel()` |
| BR-03 1–4 tickets | `@Min(1) @Max(4)` on the request; DB `CHECK (QTY BETWEEN 1 AND 4)` | `CreateBookingRequest` |
| BR-04 Server price | Request has no price field; `total = event.price × quantity`; price stored in `UNIT_PRC` | `Booking.create()` |
| BR-05 Cancelled event | Status check before reserving seats | `Event.reserveSeats()` |
| BR-06 Own bookings | Not the owner and not ADMIN → `AccessDeniedException` → 403 | `BookingServiceImpl.findAccessible()` |

## 4. Security

| Requirement | Implementation |
|---|---|
| Authentication | `POST /api/auth/login` checks BCrypt password, returns a JWT (HS256) |
| Token content | `sub` (username), `uid` (user id), `roles` (e.g. `["USER"]`), `iat`, `exp` (1 hour) |
| Token secret | Environment variable `JWT_SECRET`, at least 32 bytes; the app refuses to start otherwise |
| Session | Stateless: no server session, no cookies → CSRF protection disabled |
| Authorization (URL) | `GET /api/events/**` USER or ADMIN · other `/api/events/**` ADMIN · `/api/bookings/**` USER or ADMIN |
| Authorization (data) | Ownership check in the service (BR-06) |
| Login errors | Same message for unknown user and wrong password |
| Public URLs | `/api/auth/**`, demo page `/`, Swagger UI, `/error` |

## 5. Error handling

All errors use the RFC 9457 **ProblemDetail** JSON format, produced by `GlobalExceptionHandler`:

```json
{ "title": "Conflict", "status": 409, "detail": "Only 1 seat(s) left for event 2", "instance": "/api/bookings" }
```

| Status | Cause |
|---|---|
| 400 | Validation failed (adds an `errors` map per field), invalid JSON, unknown sort field |
| 401 | No token, invalid or expired token, wrong login |
| 403 | Wrong role, or someone else's booking |
| 404 | Event or booking not found |
| 409 | Business rule conflict (no seats, cancelled event, already cancelled) |
| 500 | Unexpected error: logged on the server, no stack trace in the response |

## 6. Non-functional requirements

| Area | Requirement | How it is met |
|---|---|---|
| Concurrency | No overbooking under parallel requests | Pessimistic row lock; test: 20 parallel bookings on 5 seats → exactly 5 succeed |
| Consistency | Seats and booking change together or not at all | `@Transactional` service methods |
| Performance | No N + 1 queries on lists | `@EntityGraph` on booking queries, `default_batch_fetch_size: 50`, indexes on `TB_BOOKING(USR_ID)` and `(EVT_ID)` |
| Paging | Max 100 rows per page | `spring.data.web.pageable.max-page-size: 100` |
| Auditing | Who/when for every insert/update | `BaseEntity` fills `REG_DTM, MOD_DTM, REG_ID, MOD_ID` |
| Maintainability | Schema versioned | Flyway migrations; Hibernate only validates (`ddl-auto: validate`) |
| Configuration | No secrets in code | DB and JWT settings from environment variables |
| Testability | Tests run anywhere | H2 in PostgreSQL mode; 21 MockMvc tests |

## 7. Conventions (from slide 22)

- Table names `TB_…`; uppercase abbreviated column names (`EVT_NM`, `AVL_SEAT`).
- Dates stored as `VARCHAR(14)` in `YYYYMMDDHH24MISS` format.
- Audit columns `REG_DTM / MOD_DTM / REG_ID / MOD_ID` on every table.
- DTOs at the API boundary; entities never returned directly.

## 8. Configuration

| Variable | Default | Purpose |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/eventtickets` | Database URL (the demo uses port 5433) |
| `DB_USERNAME` / `DB_PASSWORD` | `eventtickets` | Database login |
| `JWT_SECRET` | *(none, required)* | HS256 signing secret, ≥ 32 bytes |
| `SERVER_PORT` | `8080` | HTTP port |

---

**Next:** [ERD](ERD.md) for the database, [API Spec](API-SPEC.md) for the endpoints.
