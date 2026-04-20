// ❌ PROBLEMA F-004: secrets em arquivo de environment — visível no bundle final
// ❌ PROBLEMA U-001: apiKey e token hardcoded
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080',
  apiKey: 'sk-abc123xyz789-minha-chave-de-api',
  stripeToken: 'pk_live_51NxABCDEFGHIJKLMNOP',
  googleMapsKey: 'AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
};

// ✅ CORRETO: apenas URLs e flags não-sensíveis no environment
// export const environment = {
//   production: false,
//   apiUrl: 'http://localhost:8080',
// };
// Secrets devem vir do backend via endpoint autenticado ou variável de ambiente em build time
