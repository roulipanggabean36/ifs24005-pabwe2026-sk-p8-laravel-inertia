<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

final class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_guests_see_the_login_and_register_pages(): void
    {
        $this->get('/login')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->component('Auth/Login'));

        $this->get('/register')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->component('Auth/Register'));
    }

    public function test_member_logs_in_and_lands_on_the_dashboard(): void
    {
        $user = User::factory()->create(['username' => 'penulis', 'password' => 'rahasia123']);

        $this->post('/login', ['username' => 'penulis', 'password' => 'rahasia123'])
            ->assertRedirect(route('dashboard.posts.index'));

        $this->assertAuthenticatedAs($user);
    }

    public function test_admin_logs_in_and_lands_on_the_admin_panel(): void
    {
        $admin = User::factory()->admin()->create(['username' => 'pengelola', 'password' => 'rahasia123']);

        $this->post('/login', ['username' => 'pengelola', 'password' => 'rahasia123'])
            ->assertRedirect(route('admin.users.index'));

        $this->assertAuthenticatedAs($admin);
    }

    public function test_remember_me_queues_the_recaller_cookie(): void
    {
        User::factory()->create(['username' => 'penulis', 'password' => 'rahasia123']);

        $with = $this->post('/login', ['username' => 'penulis', 'password' => 'rahasia123', 'remember' => true]);
        $with->assertRedirect(route('dashboard.posts.index'));

        $names = array_map(fn ($cookie) => $cookie->getName(), $with->headers->getCookies());

        $this->assertNotEmpty(array_filter($names, fn (string $name) => str_starts_with($name, 'remember_web_')));
    }

    public function test_login_rejects_a_wrong_password(): void
    {
        User::factory()->create(['username' => 'penulis', 'password' => 'rahasia123']);

        $this->from('/login')
            ->post('/login', ['username' => 'penulis', 'password' => 'salah-total'])
            ->assertRedirect('/login')
            ->assertSessionHasErrors(['username' => 'Username atau kata sandi salah.']);

        $this->assertGuest();
    }

    public function test_login_rejects_an_unknown_username(): void
    {
        $this->from('/login')
            ->post('/login', ['username' => 'tidak-ada', 'password' => 'apa-saja-123'])
            ->assertSessionHasErrors(['username' => 'Username atau kata sandi salah.']);

        $this->assertGuest();
    }

    public function test_login_requires_username_and_password(): void
    {
        $this->post('/login', [])->assertSessionHasErrors(['username', 'password']);
    }

    public function test_register_creates_a_member_and_signs_in(): void
    {
        $this->post('/register', [
            'name' => 'Penulis Baru',
            'username' => 'penulis_baru',
            'password' => 'rahasia123',
            'password_confirmation' => 'rahasia123',
            'role' => 'admin',
        ])
            ->assertRedirect(route('dashboard.posts.index'))
            ->assertSessionHas('success', 'Pendaftaran berhasil. Selamat datang, Penulis Baru!');

        $user = User::query()->where('username', 'penulis_baru')->firstOrFail();

        $this->assertSame('Penulis Baru', $user->name);
        $this->assertSame('member', $user->role);
        $this->assertTrue(Hash::check('rahasia123', $user->password));
        $this->assertAuthenticatedAs($user);
    }

    public function test_register_requires_all_fields(): void
    {
        $this->post('/register', [])->assertSessionHasErrors(['name', 'username', 'password']);

        $this->assertDatabaseCount('users', 0);
    }

    public function test_register_rejects_a_taken_username(): void
    {
        User::factory()->create(['username' => 'dipakai']);

        $this->from('/register')
            ->post('/register', [
                'name' => 'Orang Lain',
                'username' => 'dipakai',
                'password' => 'rahasia123',
                'password_confirmation' => 'rahasia123',
            ])
            ->assertSessionHasErrors(['username' => 'Username sudah digunakan.']);

        $this->assertDatabaseCount('users', 1);
    }

    public function test_register_rejects_invalid_usernames(): void
    {
        foreach (['ab', 'nama pengguna', 'user.name', str_repeat('a', 51)] as $username) {
            $this->from('/register')
                ->post('/register', [
                    'name' => 'Nama',
                    'username' => $username,
                    'password' => 'rahasia123',
                    'password_confirmation' => 'rahasia123',
                ])
                ->assertSessionHasErrors('username');
        }

        $this->assertDatabaseCount('users', 0);
    }

    public function test_register_validates_the_password(): void
    {
        $base = ['name' => 'Nama', 'username' => 'penulis'];

        $this->from('/register')
            ->post('/register', $base + ['password' => 'rahasia123', 'password_confirmation' => 'berbeda123'])
            ->assertSessionHasErrors('password');

        $this->from('/register')
            ->post('/register', $base + ['password' => 'pendek', 'password_confirmation' => 'pendek'])
            ->assertSessionHasErrors(['password' => 'Kata sandi minimal 8 karakter.']);

        $this->assertDatabaseCount('users', 0);
    }

    public function test_logout_ends_the_session(): void
    {
        $this->actingAs(User::factory()->create())
            ->post('/logout')
            ->assertRedirect(route('home'));

        $this->assertGuest();
    }

    public function test_guests_cannot_log_out(): void
    {
        $this->post('/logout')->assertRedirect(route('login'));
    }

    public function test_signed_in_users_are_redirected_away_from_guest_pages(): void
    {
        $this->actingAs(User::factory()->create())
            ->get('/login')
            ->assertRedirect(route('dashboard.posts.index'));

        $this->actingAs(User::factory()->admin()->create())
            ->get('/register')
            ->assertRedirect(route('admin.users.index'));
    }
}