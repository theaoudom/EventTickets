package com.kosign.eventtickets.exception;

/** A request that is well-formed but breaks a business rule for the current state (409). */
public class ConflictException extends RuntimeException {

    public ConflictException(String message) {
        super(message);
    }
}
