package com.kosign.eventtickets.mapper;

import com.kosign.eventtickets.domain.entity.Event;
import com.kosign.eventtickets.dto.request.EventRequest;
import com.kosign.eventtickets.dto.response.EventResponse;
import org.springframework.stereotype.Component;

/** Converts between the Event entity and its DTOs. */
@Component
public class EventMapper {

    public Event toEntity(EventRequest request) {
        return new Event(request.name(), request.eventDate(), request.venue(),
                request.price(), request.totalSeats());
    }

    public EventResponse toResponse(Event event) {
        return new EventResponse(event.getId(), event.getName(), event.getEventDate(), event.getVenue(),
                event.getPrice(), event.getTotalSeats(), event.getAvailableSeats(), event.getStatus());
    }
}
