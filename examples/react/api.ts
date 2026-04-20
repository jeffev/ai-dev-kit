// ❌ ISSUE U-001: multiple hardcoded secrets
// ❌ ISSUE F-001: console.log in production code

const API_BASE = 'https://api.example.com';

// ❌ Never do this — secrets in source code are exposed in the bundle and in git history
const API_KEY = 'sk-prod-xxxxxxxxxxxxxxxxxxxxxxxxxxx';
const SECRET_TOKEN = 'eyJhbGciOiJIUzI1NiJ9.secret.token';

export async function getUsers() {
  console.log('Calling users API');

  const response = await fetch(`${API_BASE}/users`, {
    headers: {
      'Authorization': `Bearer ${SECRET_TOKEN}`,
      'X-API-Key': API_KEY,
    }
  });

  if (!response.ok) {
    console.log('Response error:', response.status);
    throw new Error('Failed to fetch users');
  }

  return response.json();
}

// ✅ CORRECT: secrets via environment variables (injected at build time by Vite)
// const API_KEY = import.meta.env.VITE_API_KEY;
// const SECRET_TOKEN = import.meta.env.VITE_SECRET_TOKEN;
// Add to .env.local — never commit that file
