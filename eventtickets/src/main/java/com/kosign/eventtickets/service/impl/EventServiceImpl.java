package com.kosign.eventtickets.service.impl;

import com.kosign.eventtickets.domain.entity.Event;
import com.kosign.eventtickets.domain.entity.enums.EventStatus;
import com.kosign.eventtickets.dto.request.EventRequest;
import com.kosign.eventtickets.dto.response.EventResponse;
import com.kosign.eventtickets.exception.NotFoundException;
import com.kosign.eventtickets.mapper.EventMapper;
import com.kosign.eventtickets.repository.EventRepository;
import com.kosign.eventtickets.service.EventService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class EventServiceImpl implements EventService {

    private final EventRepository eventRepository;
    private final EventMapper eventMapper;

    @Override
    @Transactional(readOnly = true)
    public Page<EventResponse> list(EventStatus status, Pageable pageable) {
        Page<Event> page = status == null
                ? eventRepository.findAll(pageable)
                : eventRepository.findByStatus(status, pageable);
        return page.map(eventMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public EventResponse get(Long id) {
        return eventMapper.toResponse(eventRepository.findById(id).orElseThrow(() -> notFound(id)));
    }

    @Override
    @Transactional
    public EventResponse create(EventRequest request) {
        return eventMapper.toResponse(eventRepository.save(eventMapper.toEntity(request)));
    }

    @Override
    @Transactional
    public EventResponse update(Long id, EventRequest request) {
        Event event = eventRepository.findByIdForUpdate(id).orElseThrow(() -> notFound(id));
        event.update(request.name(), request.eventDate(), request.venue(), request.price(), request.totalSeats());
        return eventMapper.toResponse(event);
    }

    @Override
    @Transactional
    public EventResponse cancel(Long id) {
        Event event = eventRepository.findByIdForUpdate(id).orElseThrow(() -> notFound(id));
        event.cancel();
        return eventMapper.toResponse(event);
    }

    private static NotFoundException notFound(Long id) {
        return new NotFoundException("Event " + id + " not found");
    }
}
