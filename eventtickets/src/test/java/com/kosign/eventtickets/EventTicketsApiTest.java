package com.kosign.eventtickets;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Seed data (V2 migration): users admin, alice, dara.
 * Event 1: 100 seats at 25.00. Event 2: 5 seats at 40.00. Event 3: CANCELLED.
 * Each test runs in a transaction that is rolled back.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class EventTicketsApiTest {

    @Autowired
    MockMvc mvc;

    // ---- auth ----

    @Test
    void loginWithWrongPasswordIs401() throws Exception {
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"alice\",\"password\":\"wrong\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void loginIgnoresAStaleOrBrokenToken() throws Exception {
        mvc.perform(post("/api/auth/login").header("Authorization", "Bearer Bearer broken")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"alice\",\"password\":\"user123\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists());
    }

    @Test
    void noTokenIs401WithJsonBody() throws Exception {
        mvc.perform(get("/api/events"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.title").value("Unauthorized"));
    }

    @Test
    void garbageTokenIs401() throws Exception {
        mvc.perform(get("/api/events").header("Authorization", "Bearer not-a-jwt"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void demoPageIsPublic() throws Exception {
        mvc.perform(get("/index.html"))
                .andExpect(status().isOk());
    }

    // ---- event role checks ----

    @Test
    void userCanListEvents() throws Exception {
        mvc.perform(get("/api/events").header("Authorization", bearer("alice", "user123")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(3))
                .andExpect(jsonPath("$.page.totalElements").value(3));
    }

    @Test
    void userCannotCreateEvent() throws Exception {
        mvc.perform(post("/api/events").header("Authorization", bearer("alice", "user123"))
                        .contentType(MediaType.APPLICATION_JSON).content(newEventJson(10)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403));
    }

    @Test
    void adminCanCreateEvent() throws Exception {
        mvc.perform(post("/api/events").header("Authorization", bearer("admin", "admin123"))
                        .contentType(MediaType.APPLICATION_JSON).content(newEventJson(10)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.availableSeats").value(10))
                .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    void invalidEventIs400WithFieldErrors() throws Exception {
        mvc.perform(post("/api/events").header("Authorization", bearer("admin", "admin123"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"eventDate\":\"2020-01-01T10:00:00\",\"venue\":\"X\",\"price\":-1,\"totalSeats\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.name").exists())
                .andExpect(jsonPath("$.errors.eventDate").exists())
                .andExpect(jsonPath("$.errors.price").exists())
                .andExpect(jsonPath("$.errors.totalSeats").exists());
    }

    @Test
    void unknownEventIs404() throws Exception {
        mvc.perform(get("/api/events/999").header("Authorization", bearer("alice", "user123")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("Event 999 not found"));
    }

    @Test
    void sortByUnknownFieldIs400() throws Exception {
        mvc.perform(get("/api/events?sort=password").header("Authorization", bearer("alice", "user123")))
                .andExpect(status().isBadRequest());
    }

    // ---- rule 1: no overbooking ----

    @Test
    void bookingMoreThanSeatsLeftIs409() throws Exception {
        String alice = bearer("alice", "user123");
        book(alice, 2, 4).andExpect(status().isCreated());         // 5 -> 1 left
        book(alice, 2, 2).andExpect(status().isConflict())
                .andExpect(jsonPath("$.detail").value("Only 1 seat(s) left for event 2"));
        book(alice, 2, 1).andExpect(status().isCreated());         // 1 -> 0 left
        book(alice, 2, 1).andExpect(status().isConflict());
    }

    // ---- rule 2: seats stay correct ----

    @Test
    void bookingReducesSeatsAndCancellingGivesThemBack() throws Exception {
        String alice = bearer("alice", "user123");
        String body = book(alice, 1, 3).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        Integer bookingId = JsonPath.read(body, "$.id");

        seatsLeft(alice, 1).andExpect(jsonPath("$.availableSeats").value(97));

        mvc.perform(post("/api/bookings/" + bookingId + "/cancel").header("Authorization", alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
        seatsLeft(alice, 1).andExpect(jsonPath("$.availableSeats").value(100));

        // Cancelling twice must not give the seats back twice
        mvc.perform(post("/api/bookings/" + bookingId + "/cancel").header("Authorization", alice))
                .andExpect(status().isConflict());
        seatsLeft(alice, 1).andExpect(jsonPath("$.availableSeats").value(100));
    }

    // ---- rule 3: 1 to 4 tickets ----

    @Test
    void quantityOutsideOneToFourIs400() throws Exception {
        String alice = bearer("alice", "user123");
        book(alice, 1, 0).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.quantity").value("must be between 1 and 4"));
        book(alice, 1, 5).andExpect(status().isBadRequest());
        book(alice, 1, 4).andExpect(status().isCreated());
    }

    // ---- rule 4: price from the server ----

    @Test
    void totalIsCalculatedByServerAndClientPriceIsIgnored() throws Exception {
        mvc.perform(post("/api/bookings").header("Authorization", bearer("alice", "user123"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"eventId\":1,\"quantity\":3,\"unitPrice\":0.01,\"totalAmount\":0.01}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.unitPrice").value(25.00))
                .andExpect(jsonPath("$.totalAmount").value(75.00));
    }

    // ---- rule 5: no booking a cancelled event ----

    @Test
    void bookingCancelledEventIs409() throws Exception {
        book(bearer("alice", "user123"), 3, 1)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.detail").value("Event 3 is cancelled"));
    }

    @Test
    void bookingIsBlockedAfterAdminCancelsEvent() throws Exception {
        mvc.perform(post("/api/events/1/cancel").header("Authorization", bearer("admin", "admin123")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
        book(bearer("alice", "user123"), 1, 1).andExpect(status().isConflict());
    }

    // ---- rule 6: only your own bookings ----

    @Test
    void customerCannotViewOrCancelSomeoneElsesBooking() throws Exception {
        String alice = bearer("alice", "user123");
        String dara = bearer("dara", "user123");
        String body = book(alice, 1, 2).andReturn().getResponse().getContentAsString();
        Integer bookingId = JsonPath.read(body, "$.id");

        mvc.perform(get("/api/bookings/" + bookingId).header("Authorization", dara))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/bookings/" + bookingId + "/cancel").header("Authorization", dara))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/bookings").header("Authorization", dara))
                .andExpect(jsonPath("$.content.length()").value(0));

        mvc.perform(get("/api/bookings/" + bookingId).header("Authorization", alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("alice"));
        mvc.perform(get("/api/bookings").header("Authorization", alice))
                .andExpect(jsonPath("$.content.length()").value(1));
    }

    @Test
    void adminCanSeeAllBookings() throws Exception {
        book(bearer("alice", "user123"), 1, 1);
        book(bearer("dara", "user123"), 1, 1);
        mvc.perform(get("/api/bookings").header("Authorization", bearer("admin", "admin123")))
                .andExpect(jsonPath("$.content.length()").value(2));
    }

    @Test
    void adminCannotShrinkEventBelowBookedSeats() throws Exception {
        book(bearer("alice", "user123"), 2, 4);
        mvc.perform(put("/api/events/2").header("Authorization", bearer("admin", "admin123"))
                        .contentType(MediaType.APPLICATION_JSON).content(newEventJson(3)))
                .andExpect(status().isConflict());
        mvc.perform(put("/api/events/2").header("Authorization", bearer("admin", "admin123"))
                        .contentType(MediaType.APPLICATION_JSON).content(newEventJson(10)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.availableSeats").value(6));
    }

    // ---- helpers ----

    private String bearer(String username, String password) throws Exception {
        String body = mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"" + username + "\",\"password\":\"" + password + "\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return "Bearer " + JsonPath.read(body, "$.accessToken");
    }

    private ResultActions book(String auth, long eventId, int quantity) throws Exception {
        return mvc.perform(post("/api/bookings").header("Authorization", auth)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"eventId\":" + eventId + ",\"quantity\":" + quantity + "}"));
    }

    private ResultActions seatsLeft(String auth, long eventId) throws Exception {
        return mvc.perform(get("/api/events/" + eventId).header("Authorization", auth));
    }

    private static String newEventJson(int seats) {
        return "{\"name\":\"Test Event\",\"eventDate\":\"2030-01-01T19:00:00\",\"venue\":\"Hall A\","
                + "\"price\":10.00,\"totalSeats\":" + seats + "}";
    }
}
