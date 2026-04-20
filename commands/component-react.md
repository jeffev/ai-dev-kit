Generate a React component for the feature described by the user.

Steps:
1. Determine: component name, props interface, state needed, any hooks or context required
2. Create the component file (.tsx):
   - Functional component with explicit Props interface (never use React.FC<>)
   - Use named export (not default export) unless it's a page/route component
   - Type all props strictly — no `any`
3. For state management:
   - Local state: useState, useReducer
   - Derived state: useMemo, useCallback with correct dependency arrays
   - Side effects: useEffect — always return cleanup function if subscribing to anything
4. Create the test file (.test.tsx):
   - Use Vitest + @testing-library/react
   - Test: renders without crashing, user interactions, async state changes
   - Use screen.getByRole / getByText — never query by className or id
5. If the component fetches data, use a custom hook (useXxx) to separate concerns

Rules:
- Never use `any` — define proper TypeScript interfaces
- Never mutate state directly — always use setState or dispatch
- Always handle loading and error states when fetching
- Keep components under 150 lines — extract sub-components or custom hooks if larger
