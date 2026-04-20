import { Component, OnInit, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

interface User {
  id: number;
  name: string;
  email: string;
}

// ❌ ISSUE F-003: subscribe() without takeUntilDestroyed or unsubscribe — memory leak
// ❌ ISSUE F-001: console.log in production code
// ❌ ISSUE F-002: `any` type used in response and error handlers
@Component({
  selector: 'app-user-list',
  standalone: true,
  template: `
    @if (loading) {
      <p>Loading...</p>
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
    console.log('Loading users');

    // ❌ F-003: subscribe with no unsubscribe strategy
    this.http.get<any>('/api/users').subscribe({
      next: (data: any) => {
        this.users = data;
        console.log('Users loaded:', data);
        this.loading = false;
      },
      error: (err: any) => {
        console.log('Error loading users', err);
        this.loading = false;
      }
    });
  }
}
