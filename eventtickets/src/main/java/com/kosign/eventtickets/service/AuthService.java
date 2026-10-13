package com.kosign.eventtickets.service;

import com.kosign.eventtickets.dto.request.LoginRequest;
import com.kosign.eventtickets.dto.response.TokenResponse;

public interface AuthService {

    /** Checks the username and password and returns a signed JWT. */
    TokenResponse login(LoginRequest request);
}
