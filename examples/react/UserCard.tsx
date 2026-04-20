import { useState, useEffect } from 'react';

// ❌ PROBLEMA F-002: uso de `any` nos tipos
// ❌ PROBLEMA F-001: console.log em produção
// ❌ PROBLEMA U-002: TODO não resolvido

interface UserCardProps {
  userId: number;
}

// TODO: adicionar skeleton loading quando dados estiverem carregando

export function UserCard({ userId }: UserCardProps) {
  // ❌ F-002: estado tipado como `any`
  const [user, setUser] = useState<any>(null);
  const [error, setError] = useState<any>(null);

  useEffect(() => {
    console.log('Buscando usuário:', userId);

    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then((data: any) => {
        console.log('Dados recebidos:', data);
        setUser(data);
      })
      .catch((err: any) => {
        console.log('Erro:', err);
        setError(err);
      });
  }, [userId]);

  if (error) return <div>Erro ao carregar usuário</div>;
  if (!user) return <div>Carregando...</div>;

  return (
    <div className="user-card">
      <h2>{user.name}</h2>
      <p>{user.email}</p>
    </div>
  );
}
