package com.kosign.eventtickets.dto.response;

import com.kosign.eventtickets.domain.entity.enums.BookingStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record BookingResponse(
        Long id,
        Long eventId,
        String eventName,
        String username,
        int quantity,
        BigDecimal unitPrice,
        BigDecimal totalAmount,
        BookingStatus status,
        LocalDateTime bookedAt
) {
}
