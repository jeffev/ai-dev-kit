Generate a test for the file or method specified by the user.

Steps:
1. Read the target file fully
2. Identify all public methods that lack a corresponding test
3. For Java: generate a JUnit 5 test class using Mockito (@ExtendWith(MockitoExtension.class))
   - One test method per scenario: happy path, null input, exception case
   - Use @InjectMocks for the class under test, @Mock for dependencies
   - Assert with AssertJ (assertThat)
4. For Angular: generate a Jasmine spec using TestBed
   - Test component creation, input/output bindings, service calls
5. For React: generate a Vitest + Testing Library test
   - Test render, user interactions, async states
6. Write the test file in the correct location:
   - Java: same package under src/test/java/
   - Angular/React: same folder as the component with .spec.ts or .test.tsx suffix

Rules:
- Do not modify the source file
- Test only public API (no private method testing)
- Each test must be independent (no shared mutable state between tests)
- Use descriptive test names: should_<expected>_when_<condition>
