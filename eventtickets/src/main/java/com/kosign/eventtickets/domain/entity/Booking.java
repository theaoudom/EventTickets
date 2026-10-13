package com.kosign.eventtickets.domain.entity;

import com.kosign.eventtickets.domain.entity.enums.BookingStatus;
import com.kosign.eventtickets.exception.ConflictException;
import com.kosign.eventtickets.util.DateTimes;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Entity
@Table(name = "TB_BOOKING")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Booking extends BaseEntity {

    public static final int MAX_TICKETS = 4;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "BKG_ID")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "EVT_ID", nullable = false)
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "USR_ID", nullable = false)
    private AppUser user;

    @Column(name = "QTY", nullable = false)
    private int quantity;

    @Column(name = "UNIT_PRC", precision = 12, scale = 2, nullable = false)
    private BigDecimal unitPrice;

    @Column(name = "TOT_AMT", precision = 12, scale = 2, nullable = false)
    private BigDecimal totalAmount;

    @Enumerated(EnumType.STRING)
    @Column(name = "STS_CD", length = 10, nullable = false)
    private BookingStatus status;

    /**
     * Reserves the seats on the event and prices the booking from the event (rule 4):
     * the client never sends a price.
     */
    public static Booking create(Event event, AppUser user, int quantity) {
        event.reserveSeats(quantity);
        Booking booking = new Booking();
        booking.event = event;
        booking.user = user;
        booking.quantity = quantity;
        booking.unitPrice = event.getPrice();
        booking.totalAmount = event.getPrice().multiply(BigDecimal.valueOf(quantity));
        booking.status = BookingStatus.BOOKED;
        return booking;
    }

    public boolean isOwnedBy(Long userId) {
        return user.getId().equals(userId);
    }

    public void cancel() {
        if (status == BookingStatus.CANCELLED) {
            throw new ConflictException("Booking " + id + " is already cancelled");
        }
        status = BookingStatus.CANCELLED;
        event.releaseSeats(quantity);
    }

    public LocalDateTime getBookedAt() {
        return DateTimes.parse(getRegDtm());
    }
}
