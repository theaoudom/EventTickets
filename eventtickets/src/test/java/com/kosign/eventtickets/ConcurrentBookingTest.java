package com.kosign.eventtickets;

import com.kosign.eventtickets.service.BookingService;
import com.kosign.eventtickets.dto.request.CreateBookingRequest;
import com.kosign.eventtickets.security.CurrentUser;
import com.kosign.eventtickets.exception.ConflictException;
import com.kosign.eventtickets.domain.entity.Event;
import com.kosign.eventtickets.repository.EventRepository;
import com.kosign.eventtickets.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Rule 1 under load: 20 parallel requests for a 5-seat event must sell exactly 5 seats.
 * Not @Transactional (each booking must really commit), so it gets its own database.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:concurrency;MODE=PostgreSQL;DATABASE_TO_UPPER=true;DB_CLOSE_DELAY=-1")
@ActiveProfiles("test")
class ConcurrentBookingTest {

    @Autowired
    BookingService bookingService;
    @Autowired
    EventRepository eventRepository;
    @Autowired
    UserRepository userRepository;

    @Test
    void parallelBookingsNeverOversell() throws Exception {
        Event event = eventRepository.save(
                new Event("Race Test", LocalDateTime.now().plusDays(30), "Hall", BigDecimal.TEN, 5));
        Long aliceId = userRepository.findByUsername("alice").orElseThrow().getId();
        CurrentUser alice = new CurrentUser(aliceId, "alice", false);

        int requests = 20;
        ExecutorService pool = Executors.newFixedThreadPool(requests);
        CountDownLatch start = new CountDownLatch(1);
        AtomicInteger booked = new AtomicInteger();
        AtomicInteger rejected = new AtomicInteger();
        List<Future<?>> futures = new ArrayList<>();
        for (int i = 0; i < requests; i++) {
            futures.add(pool.submit(() -> {
                start.await();
                try {
                    bookingService.book(alice, new CreateBookingRequest(event.getId(), 1));
                    booked.incrementAndGet();
                } catch (ConflictException e) {
                    rejected.incrementAndGet();
                }
                return null;
            }));
        }
        start.countDown();
        for (Future<?> f : futures) {
            f.get();
        }
        pool.shutdown();

        assertThat(booked.get()).isEqualTo(5);
        assertThat(rejected.get()).isEqualTo(15);
        assertThat(eventRepository.findById(event.getId()).orElseThrow().getAvailableSeats()).isZero();
    }
}
