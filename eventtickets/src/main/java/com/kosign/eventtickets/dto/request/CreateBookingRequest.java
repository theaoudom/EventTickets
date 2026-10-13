package com.kosign.eventtickets.dto.request;

import com.kosign.eventtickets.domain.entity.Booking;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/** No price field on purpose: the server calculates it (rule 4). */
public record CreateBookingRequest(
        @NotNull Long eventId,
        @NotNull @Min(value = 1, message = "must be between 1 and 4")
        @Max(value = Booking.MAX_TICKETS, message = "must be between 1 and 4") Integer quantity
) {
}
