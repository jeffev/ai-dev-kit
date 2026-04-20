package com.example.entity;

import jakarta.persistence.*;
import lombok.*;

// [ISSUE] J-005: @Entity missing proper equals/hashCode
// @Data generates equals/hashCode based on ALL fields — problematic with JPA lazy loading
// Correct: @EqualsAndHashCode(onlyExplicitlyIncluded = true) + @EqualsAndHashCode.Include on @Id
@Entity
@Table(name = "users")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private boolean active = true;
}
