# fase-5c1.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path 'tests/TestCase.php') -or -not (Test-Path 'tests/Support/FakeAiClient.php')) {
  Write-Host "GAGAL: jalankan fase-5a.ps1 dulu." -ForegroundColor Red
  exit 1
}

W 'tests/TestCase.php' @'
<?php

declare(strict_types=1);

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Test tidak bergantung pada hasil build Vite (public/build/manifest.json).
        $this->withoutVite();
    }

    /**
     * Pengaman: test tidak boleh berjalan di database aplikasi.
     * Dicek sebelum trait RefreshDatabase sempat menjalankan migrate:fresh.
     */
    protected function refreshApplication(): void
    {
        parent::refreshApplication();

        $default = (string) $this->app['config']->get('database.default');
        $database = (string) $this->app['config']->get("database.connections.{$default}.database");

        if ($default !== 'pgsql' || ! str_ends_with($database, '_test')) {
            throw new RuntimeException(sprintf(
                'Test harus memakai PostgreSQL dengan nama database berakhiran "_test" (sekarang: %s / %s). Periksa phpunit.xml.',
                $default,
                $database,
            ));
        }
    }
}
'@

W 'tests/Feature/AuthTest.php' @'
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
'@

W 'tests/Feature/AccessControlTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Post\Models\Post;
use App\Http\Middleware\EnsurePostOwnership;
use App\Http\Middleware\EnsureRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Routing\Route;
use Inertia\Testing\AssertableInertia as Assert;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

final class AccessControlTest extends TestCase
{
    use RefreshDatabase;

    public function test_guests_are_sent_to_the_login_page(): void
    {
        foreach (['/dashboard/posts', '/dashboard/posts/export', '/profile', '/admin/users', '/admin/posts'] as $uri) {
            $this->get($uri)->assertRedirect(route('login'));
        }
    }

    public function test_members_cannot_open_admin_pages(): void
    {
        $other = User::factory()->create();

        $this->actingAs(User::factory()->create());

        foreach (['/admin/users', '/admin/posts', '/admin/posts/export', "/admin/users/{$other->id}/posts", "/admin/users/{$other->id}/posts/export"] as $uri) {
            $this->get($uri)->assertForbidden();
        }
    }

    public function test_admins_cannot_open_member_pages(): void
    {
        $this->actingAs(User::factory()->admin()->create());

        $this->get('/dashboard/posts')->assertForbidden();
        $this->get('/dashboard/posts/export')->assertForbidden();
        $this->post('/dashboard/posts', [])->assertForbidden();
    }

    public function test_both_roles_may_open_the_profile_page(): void
    {
        foreach ([User::factory()->create(), User::factory()->admin()->create()] as $user) {
            $this->actingAs($user)->get('/profile')->assertOk();
        }
    }

    public function test_members_cannot_touch_posts_they_do_not_own(): void
    {
        $post = Post::factory()->create();

        $this->actingAs(User::factory()->create());

        $this->get("/dashboard/posts/{$post->id}")->assertForbidden();
        $this->put("/dashboard/posts/{$post->id}", [])->assertForbidden();
        $this->delete("/dashboard/posts/{$post->id}")->assertForbidden();
        $this->patch("/dashboard/posts/{$post->id}/publish")->assertForbidden();
        $this->post("/dashboard/posts/{$post->id}/cover")->assertForbidden();
        $this->delete("/dashboard/posts/{$post->id}/cover")->assertForbidden();

        $this->assertDatabaseHas('posts', ['id' => $post->id]);
    }

    public function test_missing_or_malformed_post_ids_are_not_found(): void
    {
        $this->actingAs(User::factory()->create());

        $this->get('/dashboard/posts/999999')->assertNotFound();
        $this->get('/dashboard/posts/abc')->assertNotFound();
    }

    public function test_inertia_shares_empty_props_for_guests(): void
    {
        $this->get('/login')->assertInertia(fn (Assert $page) => $page
            ->where('appName', config('app.name'))
            ->where('auth.user', null)
            ->where('flash.success', null)
            ->where('flash.error', null)
            ->where('flash.import_errors', []));
    }

    public function test_inertia_shares_the_signed_in_user(): void
    {
        $user = User::factory()->admin()->create([
            'name' => 'Ani',
            'username' => 'ani',
            'profile_photo_path' => 'profile-photos/a.jpg',
        ]);

        $this->actingAs($user)->get('/profile')->assertInertia(fn (Assert $page) => $page
            ->where('auth.user.id', $user->id)
            ->where('auth.user.name', 'Ani')
            ->where('auth.user.username', 'ani')
            ->where('auth.user.role', 'admin')
            ->where('auth.user.is_admin', true)
            ->where('auth.user.photo_url', '/storage/profile-photos/a.jpg')
            ->missing('auth.user.password'));
    }

    public function test_inertia_shares_flash_messages(): void
    {
        $this->withSession([
            'success' => 'Berhasil',
            'error' => 'Gagal',
            'import_errors' => [['row' => 2, 'message' => 'Judul wajib diisi.']],
        ])->get('/login')->assertInertia(fn (Assert $page) => $page
            ->where('flash.success', 'Berhasil')
            ->where('flash.error', 'Gagal')
            ->where('flash.import_errors.0.row', 2)
            ->where('flash.import_errors.0.message', 'Judul wajib diisi.'));
    }

    public function test_ensure_role_rejects_requests_without_a_user(): void
    {
        $request = Request::create('/x');
        $request->setUserResolver(fn () => null);

        $this->assertAbortsWith403(
            fn () => (new EnsureRole())->handle($request, fn () => response('ok'), 'admin'),
        );
    }

    public function test_ensure_role_accepts_any_of_the_listed_roles(): void
    {
        $request = Request::create('/x');
        $request->setUserResolver(fn () => User::factory()->make(['role' => 'member']));

        $response = (new EnsureRole())->handle($request, fn () => response('ok'), 'admin', 'member');

        $this->assertSame('ok', $response->getContent());
    }

    public function test_ensure_post_ownership_rejects_other_users_and_invalid_parameters(): void
    {
        $post = Post::factory()->create();
        $middleware = new EnsurePostOwnership();
        $next = fn () => response('lolos');

        $this->assertAbortsWith403(
            fn () => $middleware->handle($this->requestWithPost($post, User::factory()->create()), $next),
        );
        $this->assertAbortsWith403(
            fn () => $middleware->handle($this->requestWithPost($post, null), $next),
        );
        $this->assertAbortsWith403(
            fn () => $middleware->handle($this->requestWithPost('bukan-model', $post->user), $next),
        );
    }

    public function test_ensure_post_ownership_lets_the_owner_through(): void
    {
        $post = Post::factory()->create();

        $response = (new EnsurePostOwnership())->handle(
            $this->requestWithPost($post, $post->user),
            fn () => response('lolos'),
        );

        $this->assertSame('lolos', $response->getContent());
    }

    private function requestWithPost(mixed $post, ?User $user): Request
    {
        $request = Request::create('/dashboard/posts/1');

        $route = new Route('GET', '/dashboard/posts/{post}', fn () => null);
        $route->bind($request);
        $route->setParameter('post', $post);

        $request->setRouteResolver(fn () => $route);
        $request->setUserResolver(fn () => $user);

        return $request;
    }

    private function assertAbortsWith403(callable $callback): void
    {
        try {
            $callback();
        } catch (HttpException $exception) {
            $this->assertSame(403, $exception->getStatusCode());

            return;
        }

        $this->fail('HttpException 403 seharusnya dilempar.');
    }
}
'@

foreach ($f in @('tests/TestCase.php', 'tests/Feature/AuthTest.php', 'tests/Feature/AccessControlTest.php')) {
  php -l $f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: sintaks PHP salah di $f" -ForegroundColor Red
    php -l $f
    exit 1
  }
}
Write-Host "Lint PHP: semua file valid." -ForegroundColor Green

Write-Host ""
Write-Host "FASE 5c1 SELESAI." -ForegroundColor Green