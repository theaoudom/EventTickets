package com.kosign.eventtickets.service;

import com.kosign.eventtickets.domain.entity.enums.EventStatus;
import com.kosign.eventtickets.dto.request.EventRequest;
import com.kosign.eventtickets.dto.response.EventResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface EventService {

    Page<EventResponse> list(EventStatus status, Pageable pageable);

    EventResponse get(Long id);

    EventResponse create(EventRequest request);

    EventResponse update(Long id, EventRequest request);

    EventResponse cancel(Long id);
}
