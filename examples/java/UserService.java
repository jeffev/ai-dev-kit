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

    // ❌ ISSUE J-003: System.out.println instead of a logger
    public List<UserResponse> findAll() {
        System.out.println("Fetching all users");
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
        System.out.println("Creating user: " + request.getEmail());
        User user = User.builder()
                .name(request.getName())
                .email(request.getEmail())
                .build();
        return toResponse(userRepository.save(user));
    }

    public void delete(Long id) {
        userRepository.deleteById(id);
    }

    // ❌ ISSUE J-004: @Transactional on a private method has no effect in Spring AOP
    @Transactional
    private UserResponse toResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .name(user.getName())
                .email(user.getEmail())
                .build();
    }
}
