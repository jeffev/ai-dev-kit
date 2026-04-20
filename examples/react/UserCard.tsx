import { useState, useEffect } from 'react';

// ❌ ISSUE F-002: state and error typed as `any`
// ❌ ISSUE F-001: console.log in production code
// ❌ ISSUE U-002: unresolved TODO

interface UserCardProps {
  userId: number;
}

// TODO: add skeleton loading while data is being fetched

export function UserCard({ userId }: UserCardProps) {
  // ❌ F-002: state typed as `any`
  const [user, setUser] = useState<any>(null);
  const [error, setError] = useState<any>(null);

  useEffect(() => {
    console.log('Fetching user:', userId);

    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then((data: any) => {
        console.log('Data received:', data);
        setUser(data);
      })
      .catch((err: any) => {
        console.log('Error:', err);
        setError(err);
      });
  }, [userId]);

  if (error) return <div>Failed to load user</div>;
  if (!user) return <div>Loading...</div>;

  return (
    <div className="user-card">
      <h2>{user.name}</h2>
      <p>{user.email}</p>
    </div>
  );
}
