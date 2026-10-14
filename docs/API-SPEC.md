# API Specification

**Base URL:** `http://localhost:8080` (the `/demo` skill uses the first free port from 8090) · **Format:** JSON
**Interactive docs:** Swagger UI at `/swagger-ui.html`, OpenAPI JSON at `/v3/api-docs`

## Overview

| Method | Path | Who | Success | Description |
|---|---|---|---|---|
| POST | `/api/auth/login` | public | 200 | Log in, get a JWT |
| GET | `/api/events` | USER, ADMIN | 200 | List events (paged) |
| GET | `/api/events/{id}` | USER, ADMIN | 200 | One event |
| POST | `/api/events` | ADMIN | 201 | Create an event |
| PUT | `/api/events/{id}` | ADMIN | 200 | Update an event |
| POST | `/api/events/{id}/cancel` | ADMIN | 200 | Cancel an event |
| POST | `/api/bookings` | USER, ADMIN | 201 | Book tickets |
| GET | `/api/bookings` | USER, ADMIN | 200 | My bookings (ADMIN: all) |
| GET | `/api/bookings/{id}` | owner, ADMIN | 200 | One booking |
| POST | `/api/bookings/{id}/cancel` | owner, ADMIN | 200 | Cancel a booking |

## Authentication

1. Call `POST /api/auth/login` to get an `accessToken`.
2. Send it on every other request:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

The token is valid for **1 hour** (`expiresIn` = 3600 seconds). After that, log in again.

---

## Auth

### POST /api/auth/login

| Field | Type | Rules |
|---|---|---|
| `username` | string | required |
| `password` | string | required |

```http
POST /api/auth/login
Content-Type: application/json

{ "username": "alice", "password": "user123" }
```

**200 OK**
```json
{ "accessToken": "eyJhbGciOiJIUzI1NiJ9...", "tokenType": "Bearer", "expiresIn": 3600 }
```

**401** wrong username or password (same message for both). Any `Authorization` header sent to this endpoint is ignored.

---

## Events

### Event object

| Field | Type | Description |
|---|---|---|
| `id` | number | Event id |
| `name` | string | Event name |
| `eventDate` | string (ISO date-time) | e.g. `2026-11-15T19:00:00` |
| `venue` | string | Venue |
| `price` | number | Ticket price |
| `totalSeats` | number | Total seats |
| `availableSeats` | number | Seats left |
| `status` | string | `ACTIVE` or `CANCELLED` |

### GET /api/events

| Query param | Default | Description |
|---|---|---|
| `status` | (all) | `ACTIVE` or `CANCELLED` |
| `page` | `0` | Page number, starts at 0 |
| `size` | `20` | Page size, max `100` |
| `sort` | `eventDtm,asc` | Entity field and direction, e.g. `price,desc`, `name,asc`, `id,desc` |

```http
GET /api/events?status=ACTIVE&page=0&size=20&sort=price,desc
Authorization: Bearer <token>
```

**200 OK**
```json
{
  "content": [
    { "id": 1, "name": "Angkor Jazz Night", "eventDate": "2026-11-15T19:00:00", "venue": "Chaktomuk Theatre",
      "price": 25.00, "totalSeats": 100, "availableSeats": 100, "status": "ACTIVE" }
  ],
  "page": { "size": 20, "number": 0, "totalElements": 1, "totalPages": 1 }
}
```

**400** unknown sort field (e.g. `sort=password`).

### GET /api/events/{id}

| Path variable | Description |
|---|---|
| `id` | Event id |

**200 OK** an event object · **404** event not found.

### POST /api/events (ADMIN)

| Field | Type | Rules |
|---|---|---|
| `name` | string | required, max 100 |
| `eventDate` | string (ISO date-time) | required, must be in the future |
| `venue` | string | required, max 100 |
| `price` | number | required, ≥ 0 |
| `totalSeats` | number | 1 to 100000 |

```http
POST /api/events
Authorization: Bearer <admin token>
Content-Type: application/json

{ "name": "Khmer New Year Show", "eventDate": "2027-04-14T18:00:00",
  "venue": "Olympic Stadium", "price": 12.50, "totalSeats": 300 }
```

**201 Created**
```json
{ "id": 4, "name": "Khmer New Year Show", "eventDate": "2027-04-14T18:00:00", "venue": "Olympic Stadium",
  "price": 12.50, "totalSeats": 300, "availableSeats": 300, "status": "ACTIVE" }
```

**400** validation failed · **403** not ADMIN.

### PUT /api/events/{id} (ADMIN)

Same body as create. Seats left are recalculated: `availableSeats = totalSeats − seats already booked`.

**200 OK** updated event · **404** not found · **409** `totalSeats` lower than the seats already booked.

### POST /api/events/{id}/cancel (ADMIN)

No body. Sets `status` to `CANCELLED`; nobody can book it afterwards.

**200 OK** cancelled event · **404** not found · **409** already cancelled.

---

## Bookings

### Booking object

| Field | Type | Description |
|---|---|---|
| `id` | number | Booking id |
| `eventId` | number | Event id |
| `eventName` | string | Event name |
| `username` | string | Customer |
| `quantity` | number | Tickets (1–4) |
| `unitPrice` | number | Event price at booking time |
| `totalAmount` | number | `unitPrice × quantity`, calculated by the server |
| `status` | string | `BOOKED` or `CANCELLED` |
| `bookedAt` | string (ISO date-time) | When it was booked |

### POST /api/bookings

| Field | Type | Rules |
|---|---|---|
| `eventId` | number | required |
| `quantity` | number | required, **1 to 4** |

There is **no price field**: any price or total sent by the client is ignored (BR-04).

```http
POST /api/bookings
Authorization: Bearer <token>
Content-Type: application/json

{ "eventId": 1, "quantity": 3 }
```

**201 Created**
```json
{ "id": 1, "eventId": 1, "eventName": "Angkor Jazz Night", "username": "alice", "quantity": 3,
  "unitPrice": 25.00, "totalAmount": 75.00, "status": "BOOKED", "bookedAt": "2026-09-28T17:43:27" }
```

| Status | When | Rule |
|---|---|---|
| 400 | `quantity` not 1–4, or missing fields | BR-03 |
| 404 | Event not found | |
| 409 | Not enough seats left: `"Only 1 seat(s) left for event 2"` | BR-01 |
| 409 | Event is cancelled: `"Event 3 is cancelled"` | BR-05 |

### GET /api/bookings

Customers get **their own** bookings; an ADMIN gets **all** bookings. Paged like events
(`page`, `size`, `sort`; default `sort=id,desc`).

**200 OK** `{ "content": [ booking, ... ], "page": { ... } }`

### GET /api/bookings/{id}

**200 OK** booking · **403** someone else's booking (BR-06) · **404** not found.

### POST /api/bookings/{id}/cancel

No body. Sets `status` to `CANCELLED` and gives the seats back to the event (BR-02).

**200 OK** cancelled booking · **403** someone else's booking (BR-06) · **404** not found ·
**409** already cancelled (seats are never returned twice).

---

## Errors

Every error uses the same **ProblemDetail** format (RFC 9457):

```json
{ "title": "Conflict", "status": 409, "detail": "Only 1 seat(s) left for event 2", "instance": "/api/bookings" }
```

Validation errors add an `errors` map with one message per field:

```json
{ "title": "Bad Request", "status": 400, "detail": "Validation failed", "instance": "/api/bookings",
  "errors": { "quantity": "must be between 1 and 4" } }
```

| Status | Title | `detail` example |
|---|---|---|
| 400 | Bad Request | `Validation failed`, `Cannot sort by 'password'` |
| 401 | Unauthorized | `Authentication is required or has failed` |
| 403 | Forbidden | `You do not have permission for this action` |
| 404 | Not Found | `Event 999 not found` |
| 409 | Conflict | `Only 1 seat(s) left for event 2`, `Event 3 is cancelled`, `Booking 1 is already cancelled` |
| 500 | Internal Server Error | `Unexpected server error` (details only in the server log) |

## curl quick start

```bash
TOKEN=$(curl -s localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"user123"}' | sed -E 's/.*"accessToken":"([^"]+)".*/\1/')

curl -s localhost:8080/api/events -H "Authorization: Bearer $TOKEN"

curl -s localhost:8080/api/bookings -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"eventId":1,"quantity":2}'
```
