# Project documents

Read them in this order: each one builds on the previous.

| # | Document | Answers | For |
|---|---|---|---|
| 1 | [BRD – Business Requirements](BRD.md) | **Why** are we building this? | Business, mentor |
| 2 | [PRD – Product Requirements](PRD.md) | **What** does the product do? | Product owner, QA |
| 3 | [ERD – Database design](ERD.md) | How is the data stored? | Developers, DBA |
| 4 | [API Spec](API-SPEC.md) | How do clients call it? | Frontend / mobile developers |

```
BRD (why) ──► PRD (what) ──► ERD + API Spec (how) ──► Code + tests ──► Demo
```

**Source of the requirements:** the course deck *Backend Development with Spring Boot* (KOSIGN Cambodia):
slide 23 gives the business rules, slide 22 the technical requirements. These documents turn those slides into
the standard document set and describe what was actually built.
