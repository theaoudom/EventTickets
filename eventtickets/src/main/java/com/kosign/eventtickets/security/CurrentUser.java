package com.kosign.eventtickets.security;

import org.springframework.security.oauth2.jwt.Jwt;

import java.util.List;

/** The caller, read from the verified JWT. */
public record CurrentUser(Long id, String username, boolean admin) {

    public static CurrentUser from(Jwt jwt) {
        List<String> roles = jwt.getClaimAsStringList("roles");
        return new CurrentUser(
                ((Number) jwt.getClaim("uid")).longValue(),
                jwt.getSubject(),
                roles != null && roles.contains("ADMIN"));
    }
}
