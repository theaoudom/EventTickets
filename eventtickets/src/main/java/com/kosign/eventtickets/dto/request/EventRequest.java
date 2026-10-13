package com.kosign.eventtickets.dto.request;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record EventRequest(
        @NotBlank @Size(max = 100) String name,
        @NotNull @Future LocalDateTime eventDate,
        @NotBlank @Size(max = 100) String venue,
        @NotNull @PositiveOrZero BigDecimal price,
        @Positive @Max(100_000) int totalSeats
) {
}
