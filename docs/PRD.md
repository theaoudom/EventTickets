# PRD – Product Requirements Document

**Project:** Event Tickets API · **Version:** 1.0 · **Date:** October 2026 · **Owner:** Thea Oudom
**Based on:** [BRD](BRD.md)

> A PRD explains **what** the product does: who uses it, which features it has, and how we know each feature is done
> (acceptance criteria). It does not explain how the code works.

---

## 1. Product summary

A REST API that lets **customers** book tickets for events and lets **admins** manage events. It guarantees correct
seat counts and prices, even under heavy load. Clients (web or mobile apps) talk to it over HTTP with JSON.

## 2. Users and roles

| Role | Who | Can do |
|---|---|---|
| **USER** (customer) | People buying tickets | Log in, list and view events, book tickets, view and cancel **own** bookings |
| **ADMIN** | Event organizers | Everything a USER can, plus create, update and cancel events, and view all bookings |
| **Guest** (not logged in) | Anyone | Only log in |

Demo accounts: `admin / admin123` (ADMIN), `alice / user123` and `bob / user123` (USER).

## 3. User stories

| ID | As a… | I want to… | So that… | Priority |
|---|---|---|---|---|
| US-01 | user | log in with username and password | I can use the system securely | Must |
| US-02 | customer | see the list of events with price and seats left | I can choose what to book | Must |
| US-03 | customer | book 1 to 4 tickets for an event | I get my tickets | Must |
| US-04 | customer | see my bookings | I know what I bought | Must |
| US-05 | customer | cancel my booking | the seats go back to others | Must |
| US-06 | admin | create an event with name, date, venue, price and seats | customers can book it | Must |
| US-07 | admin | update an event | I can fix details or add seats | Should |
| US-08 | admin | cancel an event | nobody books an event that won't happen | Must |
| US-09 | admin | see all bookings | I can help customers | Should |

## 4. Features and acceptance criteria

Each criterion is written as **Given / When / Then** and is covered by an automated test.

### F-01 Login (US-01)
- **Given** a valid username and password, **when** I log in, **then** I get a token valid for 1 hour.
- **Given** a wrong password or unknown username, **when** I log in, **then** I get **401** with the same message for both.
- **Given** no token or an invalid token, **when** I call any other endpoint, **then** I get **401**.

### F-02 Events (US-02, US-06, US-07, US-08)
- Logged-in users can list events (paged, sortable, filter by status) and view one event.
- **Given** I am a USER, **when** I create, update or cancel an event, **then** I get **403**.
- **Given** I am an ADMIN, **when** I create a valid event, **then** I get **201** and seats left = total seats.
- **Given** invalid data (empty name, past date, negative price, 0 seats), **then** I get **400** with the field errors.
- **Given** 4 seats are booked, **when** the admin sets total seats to 3, **then** I get **409** (can't go below booked seats).
- **Given** an unknown event id, **then** I get **404**.

### F-03 Booking (US-03) – business rules BR-01, BR-03, BR-04, BR-05
| Rule | Given | When | Then |
|---|---|---|---|
| BR-03 | an active event | I book 0 or 5 tickets | **400**, "must be between 1 and 4" |
| BR-03 | an active event | I book 4 tickets | **201** |
| BR-01 | an event with 1 seat left | I book 2 tickets | **409**, "Only 1 seat(s) left" |
| BR-01 | an event with 5 seats and 20 customers booking at once | each books 1 ticket | exactly **5 succeed**, 15 get **409** |
| BR-04 | an event priced 25.00 | I book 3 tickets and send a price of 0.01 | **201**, total = **75.00** |
| BR-05 | a CANCELLED event | I book it | **409**, "Event … is cancelled" |

### F-04 My bookings (US-04, US-05, US-09) – business rules BR-02, BR-06
| Rule | Given | When | Then |
|---|---|---|---|
| BR-02 | an event with 100 seats | I book 3, then cancel | seats 100 → 97 → **100** |
| BR-02 | a cancelled booking | I cancel it again | **409**, seats unchanged |
| BR-06 | Alice's booking | Bob views or cancels it | **403** |
| BR-06 | Alice's booking | Alice views it | **200** |
| BR-06 | bookings from Alice and Bob | Bob lists his bookings | only Bob's bookings |
| — | bookings from many customers | an ADMIN lists bookings | all bookings |

## 5. Non-functional requirements

| Area | Requirement |
|---|---|
| Correctness under load | No overbooking with concurrent requests (BR-01) |
| Security | Passwords hashed (BCrypt); token expires after 1 hour; secret not stored in code |
| Errors | Every error returns the same JSON format with a clear message |
| Paging | Lists are paged; maximum 100 items per page |
| Auditing | Every row records who created/changed it and when |
| Documentation | Swagger UI for all endpoints; demo page for every rule |

## 6. Out of scope

Payment, refunds, notifications, seat maps, customer registration, and automatically cancelling bookings when an
event is cancelled (future work).

## 7. Release checklist

- [x] All user stories marked **Must** implemented
- [x] All acceptance criteria covered by tests (`./gradlew test`: 21 tests pass)
- [x] Live demo of every rule on the demo page
- [x] API documented in Swagger and [API Spec](API-SPEC.md)

---

**Next:** [SRS](SRS.md) explains how the system is built to meet these requirements.
