import { Component, OnInit, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

interface User {
  id: number;
  name: string;
  email: string;
}

// ❌ PROBLEMA F-003: subscribe() sem takeUntilDestroyed ou unsubscribe — memory leak
// ❌ PROBLEMA F-001: console.log em código de produção
// ❌ PROBLEMA F-002: uso de `any` no tipo de resposta
@Component({
  selector: 'app-user-list',
  standalone: true,
  template: `
    @if (loading) {
      <p>Carregando...</p>
    } @else {
      @for (user of users; track user.id) {
        <div>{{ user.name }} — {{ user.email }}</div>
      }
    }
  `
})
export class UserListComponent implements OnInit {
  private http = inject(HttpClient);

  users: User[] = [];
  loading = false;

  ngOnInit() {
    this.loading = true;
    console.log('Iniciando carregamento de usuários');

    // ❌ F-003: subscribe sem estratégia de unsubscribe
    this.http.get<any>('/api/users').subscribe({
      next: (data: any) => {
        this.users = data;
        console.log('Usuários carregados:', data);
        this.loading = false;
      },
      error: (err: any) => {
        console.log('Erro ao carregar usuários', err);
        this.loading = false;
      }
    });
  }
}
