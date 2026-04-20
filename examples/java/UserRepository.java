package com.example.repository;

import com.example.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    // ✅ CORRECT: named parameter with @Query
    @Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
    Optional<User> findActiveByEmail(String email);
}

// Separate example to demonstrate SQL Injection
class UserSearchService {

    private final JdbcTemplate jdbcTemplate;

    UserSearchService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    // ❌ ISSUE J-001: SQL Injection — user input concatenated directly into query
    public List<User> searchByName(String name) {
        String query = "SELECT * FROM users WHERE name = '" + name + "'";
        return jdbcTemplate.query(query, (rs, row) -> new User());
    }

    // ✅ CORRECT: PreparedStatement with parameter binding
    public List<User> searchByNameSafe(String name) {
        return jdbcTemplate.query(
            "SELECT * FROM users WHERE name = ?",
            new Object[]{name},
            (rs, row) -> new User()
        );
    }
}
