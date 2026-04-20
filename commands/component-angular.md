Generate a standalone Angular component for the feature described by the user.

Steps:
1. Determine: component name, purpose, inputs/outputs needed, any services to inject
2. Create the component file (kebab-case folder + files):
   - Use standalone: true (no NgModule)
   - Inject services with inject() function, not constructor parameters
   - Use signals (signal(), computed(), effect()) for reactive state
   - Use the OnPush change detection strategy: changeDetection: ChangeDetectionStrategy.OnPush
3. Create the template (.html):
   - Use @if / @for / @switch (Angular 17+ control flow syntax, not *ngIf/*ngFor)
   - Bind to signals with ()  e.g., {{ mySignal() }}
4. Create the styles file (.scss) with component-scoped styles only
5. Create the spec file (.spec.ts):
   - Use TestBed.configureTestingModule with standalone component
   - Test: component creates successfully, inputs render correctly, outputs emit on interaction
6. If the component is routed, add the route to the appropriate routes file

Rules:
- Never use NgModule for new components
- Never use constructor injection — always inject()
- Never use ngModel — use reactive forms (FormControl, FormGroup) or signal-based state
- Always unsubscribe from observables with takeUntilDestroyed()
