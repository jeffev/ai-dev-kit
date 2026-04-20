package com.example.service;

import com.example.dto.UserRequest;
import com.example.dto.UserResponse;
import com.example.entity.User;
import com.example.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    // ❌ PROBLEMA J-003: System.out.println em vez de logger
    // ❌ PROBLEMA J-004: @Transactional em método privado (não tem efeito)
    public List<UserResponse> findAll() {
        System.out.println("Buscando todos os usuários");
        return userRepository.findAll()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    public UserResponse findById(Long id) {
        return userRepository.findById(id)
                .map(this::toResponse)
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    public UserResponse create(UserRequest request) {
        System.out.println("Criando usuário: " + request.getEmail());
        User user = User.builder()
                .name(request.getName())
                .email(request.getEmail())
                .build();
        return toResponse(userRepository.save(user));
    }

    public void delete(Long id) {
        userRepository.deleteById(id);
    }

    // ❌ PROBLEMA J-004: @Transactional em método privado não funciona no Spring
    @Transactional
    private UserResponse toResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .name(user.getName())
                .email(user.getEmail())
                .build();
    }
}
