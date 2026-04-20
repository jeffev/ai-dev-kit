// ❌ PROBLEMA U-001: múltiplos secrets hardcoded
// ❌ PROBLEMA F-001: console.log em produção

const API_BASE = 'https://api.example.com';

// ❌ nunca faça isso — secrets no código fonte são expostos no bundle e no git
const API_KEY = 'sk-prod-xxxxxxxxxxxxxxxxxxxxxxxxxxx';
const SECRET_TOKEN = 'eyJhbGciOiJIUzI1NiJ9.secret.token';

export async function getUsers() {
  console.log('Chamando API de usuários');

  const response = await fetch(`${API_BASE}/users`, {
    headers: {
      'Authorization': `Bearer ${SECRET_TOKEN}`,
      'X-API-Key': API_KEY,
    }
  });

  if (!response.ok) {
    console.log('Erro na resposta:', response.status);
    throw new Error('Falha ao buscar usuários');
  }

  return response.json();
}

// ✅ CORRETO: secrets via variáveis de ambiente (injetadas em build time pelo Vite)
// const API_KEY = import.meta.env.VITE_API_KEY;
// const SECRET_TOKEN = import.meta.env.VITE_SECRET_TOKEN;
// Adicionar ao .env.local (nunca commitar esse arquivo)
