package com.kosign.eventtickets.domain.entity;

import com.kosign.eventtickets.domain.entity.enums.EventStatus;
import com.kosign.eventtickets.exception.ConflictException;
import com.kosign.eventtickets.util.DateTimes;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Entity
@Table(name = "TB_EVENT")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Event extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "EVT_ID")
    private Long id;

    @Column(name = "EVT_NM", length = 100, nullable = false)
    private String name;

    @Column(name = "EVT_DTM", length = 14, nullable = false)
    private String eventDtm;

    @Column(name = "VENUE_NM", length = 100, nullable = false)
    private String venue;

    @Column(name = "PRICE", precision = 12, scale = 2, nullable = false)
    private BigDecimal price;

    @Column(name = "TOT_SEAT", nullable = false)
    private int totalSeats;

    @Column(name = "AVL_SEAT", nullable = false)
    private int availableSeats;

    @Enumerated(EnumType.STRING)
    @Column(name = "STS_CD", length = 10, nullable = false)
    private EventStatus status;

    public Event(String name, LocalDateTime eventDate, String venue, BigDecimal price, int totalSeats) {
        this.name = name;
        this.eventDtm = DateTimes.format(eventDate);
        this.venue = venue;
        this.price = price;
        this.totalSeats = totalSeats;
        this.availableSeats = totalSeats;
        this.status = EventStatus.ACTIVE;
    }

    public LocalDateTime getEventDate() {
        return DateTimes.parse(eventDtm);
    }

    public boolean isCancelled() {
        return status == EventStatus.CANCELLED;
    }

    public void update(String name, LocalDateTime eventDate, String venue, BigDecimal price, int totalSeats) {
        int booked = this.totalSeats - this.availableSeats;
        if (totalSeats < booked) {
            throw new ConflictException(
                    "Total seats cannot be less than the " + booked + " seats already booked");
        }
        this.name = name;
        this.eventDtm = DateTimes.format(eventDate);
        this.venue = venue;
        this.price = price;
        this.totalSeats = totalSeats;
        this.availableSeats = totalSeats - booked;
    }

    public void cancel() {
        if (isCancelled()) {
            throw new ConflictException("Event " + id + " is already cancelled");
        }
        this.status = EventStatus.CANCELLED;
    }

    /** Rules 1 and 5: no overbooking, no booking a cancelled event. */
    public void reserveSeats(int quantity) {
        if (isCancelled()) {
            throw new ConflictException("Event " + id + " is cancelled");
        }
        if (quantity > availableSeats) {
            throw new ConflictException(
                    "Only " + availableSeats + " seat(s) left for event " + id);
        }
        availableSeats -= quantity;
    }

    /** Rule 2: cancelling a booking gives the seats back. */
    public void releaseSeats(int quantity) {
        availableSeats = Math.min(totalSeats, availableSeats + quantity);
    }
}
