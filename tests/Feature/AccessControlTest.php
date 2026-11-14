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