package com.kosign.eventtickets.dto.response;

import com.kosign.eventtickets.domain.entity.enums.EventStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record EventResponse(
        Long id,
        String name,
        LocalDateTime eventDate,
        String venue,
        BigDecimal price,
        int totalSeats,
        int availableSeats,
        EventStatus status
) {
}
