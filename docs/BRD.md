# BRD – Business Requirements Document

**Project:** Event Tickets API · **Version:** 1.0 · **Date:** October 2026 · **Owner:** Thea Oudom
**Source:** course homework, *Backend Development with Spring Boot*, slide 23

> A BRD explains **why** a project exists and what the business needs from it, in business language.
> It does not describe screens, APIs or databases.

---

## 1. Background

Event organizers sell a fixed number of seats for each event. Customers book tickets online. When many customers
book at the same time, a simple system can **sell more tickets than there are seats**, charge the wrong price,
or let one customer see or cancel another customer's booking. Each of these costs money and trust.

## 2. Business problem

| Problem | Business impact |
|---|---|
| Overbooking: more tickets sold than seats | Customers turned away at the door, refunds, complaints |
| Seat counts drift after cancellations | Seats appear sold out when they are free → lost sales |
| Customers book large blocks of tickets | Ticket scalping, unfair access for other customers |
| Price sent by the customer's app is trusted | Customers can pay less than the real price → revenue loss |
| Tickets sold for cancelled events | Refunds, complaints |
| Customers can see or cancel others' bookings | Privacy breach, fraud |

## 3. Business goals

1. **Never oversell** an event, even when many customers book at the same moment.
2. **Seat counts are always correct** after bookings and cancellations.
3. **Fair access:** limit how many tickets one booking can contain.
4. **Correct revenue:** the price always comes from the organizer, never from the customer.
5. **No sales for cancelled events.**
6. **Privacy:** customers only see and manage their own bookings.

## 4. Stakeholders

| Stakeholder | Interest |
|---|---|
| Customer | Book tickets quickly, see and cancel own bookings |
| Event organizer (admin) | Publish events, set price and seats, cancel events |
| Business owner | Correct revenue, no overbooking complaints |
| Developers / mentor | A clear, secure, testable backend |

## 5. Scope

**In scope**

- Customer login
- Listing events and seeing seats left
- Booking 1–4 tickets for an event
- Viewing and cancelling own bookings
- Admin: create, update and cancel events

**Out of scope (future)**

- Online payment and refunds
- Email / SMS notifications
- Seat maps (choosing a specific seat)
- Customer self-registration

## 6. Business rules

| ID | Rule | When broken, the system must… |
|---|---|---|
| **BR-01** | **No overbooking:** a booking cannot take more tickets than seats left | refuse with **409 Conflict** |
| **BR-02** | **Seats stay correct:** booking reduces seats, cancelling gives them back | (always true; a booking cannot be cancelled twice) |
| **BR-03** | **Max 4 tickets per booking:** quantity must be 1 to 4 | refuse with **400 Bad Request** |
| **BR-04** | **Price from the server:** total = event price × quantity | ignore any price sent by the customer |
| **BR-05** | **No booking a cancelled event** | refuse with **409 Conflict** |
| **BR-06** | **Only your own bookings:** customers view or cancel only their own bookings | refuse with **403 Forbidden** |

## 7. Assumptions and constraints

- Each user has one role: **customer** or **admin**.
- A booking keeps the price paid at booking time, even if the event price changes later.
- Cancelled bookings and events are kept (status CANCELLED) for history, not deleted.
- Technology is fixed by the course: Spring Boot 4, Java 21, PostgreSQL.

## 8. Success criteria

| Measure | Target |
|---|---|
| Oversold events | **0**, including when 20 customers book the last seats at the same moment |
| Business rules BR-01 … BR-06 | Each one passes an automated test and the live demo |
| Wrong totals charged | **0** (price always calculated by the server) |
| Customers able to access others' bookings | **0** |

---

**Next:** [PRD](PRD.md) describes the product features that meet these business needs.
