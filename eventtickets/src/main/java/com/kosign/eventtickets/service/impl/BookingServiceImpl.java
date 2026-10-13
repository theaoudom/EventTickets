package com.kosign.eventtickets.service.impl;

import com.kosign.eventtickets.domain.entity.Booking;
import com.kosign.eventtickets.domain.entity.Event;
import com.kosign.eventtickets.dto.request.CreateBookingRequest;
import com.kosign.eventtickets.dto.response.BookingResponse;
import com.kosign.eventtickets.exception.NotFoundException;
import com.kosign.eventtickets.mapper.BookingMapper;
import com.kosign.eventtickets.repository.BookingRepository;
import com.kosign.eventtickets.repository.EventRepository;
import com.kosign.eventtickets.repository.UserRepository;
import com.kosign.eventtickets.security.CurrentUser;
import com.kosign.eventtickets.service.BookingService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class BookingServiceImpl implements BookingService {

    private final BookingRepository bookingRepository;
    private final EventRepository eventRepository;
    private final UserRepository userRepository;
    private final BookingMapper bookingMapper;

    @Override
    @Transactional
    public BookingResponse book(CurrentUser me, CreateBookingRequest request) {
        // Lock the event row so concurrent bookings cannot oversell the last seats
        Event event = eventRepository.findByIdForUpdate(request.eventId())
                .orElseThrow(() -> new NotFoundException("Event " + request.eventId() + " not found"));
        Booking booking = Booking.create(event, userRepository.getReferenceById(me.id()), request.quantity());
        return bookingMapper.toResponse(bookingRepository.save(booking));
    }

    @Override
    @Transactional(readOnly = true)
    public Page<BookingResponse> list(CurrentUser me, Pageable pageable) {
        Page<Booking> page = me.admin()
                ? bookingRepository.findAll(pageable)
                : bookingRepository.findByUserId(me.id(), pageable);
        return page.map(bookingMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public BookingResponse get(CurrentUser me, Long id) {
        return bookingMapper.toResponse(findAccessible(me, id));
    }

    @Override
    @Transactional
    public BookingResponse cancel(CurrentUser me, Long id) {
        Booking booking = findAccessible(me, id);
        // Lock the event before giving seats back, same as when booking
        eventRepository.findByIdForUpdate(booking.getEvent().getId());
        booking.cancel();
        return bookingMapper.toResponse(booking);
    }

    /** Rule 6: someone else's booking is 403, not 404. */
    private Booking findAccessible(CurrentUser me, Long id) {
        Booking booking = bookingRepository.findWithDetailsById(id)
                .orElseThrow(() -> new NotFoundException("Booking " + id + " not found"));
        if (!me.admin() && !booking.isOwnedBy(me.id())) {
            throw new AccessDeniedException("Booking " + id + " belongs to another customer");
        }
        return booking;
    }
}
