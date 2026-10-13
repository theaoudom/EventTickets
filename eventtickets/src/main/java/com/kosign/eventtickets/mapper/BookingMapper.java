package com.kosign.eventtickets.mapper;

import com.kosign.eventtickets.domain.entity.Booking;
import com.kosign.eventtickets.dto.response.BookingResponse;
import org.springframework.stereotype.Component;

/** Converts the Booking entity to its response DTO. */
@Component
public class BookingMapper {

    public BookingResponse toResponse(Booking booking) {
        return new BookingResponse(booking.getId(), booking.getEvent().getId(), booking.getEvent().getName(),
                booking.getUser().getUsername(), booking.getQuantity(), booking.getUnitPrice(),
                booking.getTotalAmount(), booking.getStatus(), booking.getBookedAt());
    }
}
