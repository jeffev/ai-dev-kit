package com.example.config;

import io.jsonwebtoken.security.Keys;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.security.Key;

@Configuration
public class AuthConfig {

    // [ISSUE] J-006: hardcoded JWT secret — never do this in production
    private String jwtSecret = "my-super-secret-key-123456789";

    // [ISSUE] U-001: hardcoded password
    private String adminPassword = "admin123";

    // [CORRECT]: inject via @Value
    // @Value("${jwt.secret}")
    // private String jwtSecret;

    @Bean
    public Key signingKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes());
    }
}
