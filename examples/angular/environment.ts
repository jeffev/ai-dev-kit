// ❌ ISSUE F-004: secrets in environment file — visible in the final bundle
// ❌ ISSUE U-001: apiKey and token hardcoded in source code
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080',
  apiKey: 'sk-abc123xyz789-my-api-key',
  stripeToken: 'pk_live_51NxABCDEFGHIJKLMNOP',
  googleMapsKey: 'AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
};

// ✅ CORRECT: only non-sensitive URLs and flags in the environment file
// export const environment = {
//   production: false,
//   apiUrl: 'http://localhost:8080',
// };
// Secrets should come from the backend via an authenticated endpoint
// or be injected as build-time environment variables
