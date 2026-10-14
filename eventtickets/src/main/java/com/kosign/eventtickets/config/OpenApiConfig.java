package com.kosign.eventtickets.config;

import com.kosign.eventtickets.domain.entity.Event;
import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import org.springframework.context.annotation.Configuration;

/**
 * Swagger UI at /swagger-ui.html. Log in via POST /api/auth/login, then paste the
 * accessToken into the "Authorize" button.
 */
@Configuration
@OpenAPIDefinition(
        info = @Info(title = "Event Tickets API", version = "v1",
                description = "Homework: book event tickets. Users: admin/admin123, alice/user123, dara/user123"),
        security = @SecurityRequirement(name = "bearerAuth"))
@SecurityScheme(name = "bearerAuth", type = SecuritySchemeType.HTTP, scheme = "bearer", bearerFormat = "JWT")
public class OpenApiConfig {
}
