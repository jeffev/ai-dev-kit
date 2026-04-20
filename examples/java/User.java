package com.example.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

// ❌ PROBLEMA J-005: @Entity sem equals/hashCode adequado
// @Data gera equals/hashCode baseado em TODOS os campos — problemático com JPA
// Correto: @EqualsAndHashCode(onlyExplicitlyIncluded = true) + @EqualsAndHashCode.Include no @Id
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
