package com.kosign.eventtickets.service;

import com.kosign.eventtickets.dto.request.CreateBookingRequest;
import com.kosign.eventtickets.dto.response.BookingResponse;
import com.kosign.eventtickets.security.CurrentUser;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface BookingService {

    BookingResponse book(CurrentUser me, CreateBookingRequest request);

    /** Customers see their own bookings; an admin sees all of them. */
    Page<BookingResponse> list(CurrentUser me, Pageable pageable);

    BookingResponse get(CurrentUser me, Long id);

    BookingResponse cancel(CurrentUser me, Long id);
}
