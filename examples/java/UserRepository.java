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

    // ✅ CORRETO: named parameter com @Query
    @Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
    Optional<User> findActiveByEmail(String email);
}

// Exemplo separado para mostrar SQL Injection
class UserSearchService {

    private final JdbcTemplate jdbcTemplate;

    UserSearchService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    // ❌ PROBLEMA J-001: SQL Injection — input do usuário concatenado diretamente
    public List<User> searchByName(String name) {
        String query = "SELECT * FROM users WHERE name = '" + name + "'";
        return jdbcTemplate.query(query, (rs, row) -> new User());
    }

    // ✅ CORRETO: PreparedStatement com parâmetro
    public List<User> searchByNameSafe(String name) {
        return jdbcTemplate.query(
            "SELECT * FROM users WHERE name = ?",
            new Object[]{name},
            (rs, row) -> new User()
        );
    }
}
