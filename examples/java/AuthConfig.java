package com.example.config;

import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.security.Key;

@Configuration
public class AuthConfig {

    // ❌ PROBLEMA J-006: JWT secret hardcoded — nunca faça isso em produção
    private String jwtSecret = "minha-chave-super-secreta-123456789";

    // ❌ PROBLEMA U-001: token/password hardcoded
    private String adminPassword = "admin123";

    // ✅ CORRETO: injetar via @Value
    // @Value("${jwt.secret}")
    // private String jwtSecret;

    @Bean
    public Key signingKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes());
    }
}
