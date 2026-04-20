Scaffold a complete REST endpoint for the feature described by the user.

Steps:
1. Ask (or infer from context): entity name, HTTP methods needed, required roles
2. Create Entity class in src/main/java/.../entity/
   - Annotations: @Entity, @Table, @Data, @Builder, @NoArgsConstructor, @AllArgsConstructor
   - @Id with @GeneratedValue(strategy = GenerationType.IDENTITY)
   - @EqualsAndHashCode(onlyExplicitlyIncluded = true) with @EqualsAndHashCode.Include on @Id
3. Create Repository interface in src/main/java/.../repository/
   - Extends JpaRepository<Entity, Long>
4. Create Request and Response DTOs in src/main/java/.../dto/
5. Create MapStruct @Mapper interface in src/main/java/.../mapper/
6. Create @Service class in src/main/java/.../service/
   - @RequiredArgsConstructor for constructor injection
   - Full CRUD methods with proper exception handling (throw ApiException or equivalent)
7. Create @RestController in src/main/java/.../controller/
   - @PreAuthorize on every method
   - Delegate all logic to service — no business logic in controller
   - Return ResponseEntity<> with appropriate HTTP status codes
8. Create unit test for the service in src/test/java/

Rules:
- Never use @Autowired — always constructor injection via @RequiredArgsConstructor
- Never return Entity directly from controller — always use Response DTO
- Never put @Transactional on private methods
