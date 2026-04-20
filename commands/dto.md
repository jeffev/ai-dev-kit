Generate a DTO (Data Transfer Object) and MapStruct mapper for the entity specified by the user.

Steps:
1. Read the target Entity class fully
2. Create XxxRequest DTO:
   - Include only fields accepted from the client
   - Add Bean Validation annotations (@NotNull, @NotBlank, @Size, @Email as appropriate)
   - Annotations: @Data, @Builder, @NoArgsConstructor, @AllArgsConstructor
3. Create XxxResponse DTO:
   - Include all fields the client should receive
   - Never include: passwordHash, internal audit fields unless explicitly requested
   - Annotations: @Data, @Builder, @NoArgsConstructor, @AllArgsConstructor
4. Create XxxMapper interface:
   - Annotate with @Mapper(componentModel = "spring")
   - Map Entity → Response DTO
   - Map Request DTO → Entity
   - If field names differ, use @Mapping(source = "...", target = "...")
5. Place files in the correct packages (dto/, mapper/)

Rules:
- DTOs must never extend or reference Entity classes
- Mappers must never contain business logic
- If a field should be ignored in mapping, use @Mapping(target = "field", ignore = true)
