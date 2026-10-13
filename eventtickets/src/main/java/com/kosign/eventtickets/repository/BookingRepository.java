package com.kosign.eventtickets.repository;

import com.kosign.eventtickets.domain.entity.Booking;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

/** @EntityGraph loads event and user in the same query, so lists do not hit N + 1. */
public interface BookingRepository extends JpaRepository<Booking, Long> {

    @EntityGraph(attributePaths = {"event", "user"})
    Page<Booking> findByUserId(Long userId, Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"event", "user"})
    Page<Booking> findAll(Pageable pageable);

    @EntityGraph(attributePaths = {"event", "user"})
    Optional<Booking> findWithDetailsById(Long id);
}
