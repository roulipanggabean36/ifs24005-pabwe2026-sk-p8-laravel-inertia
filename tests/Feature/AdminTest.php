<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\Support\ReadsDownloads;
use Tests\TestCase;

final class AdminTest extends TestCase
{
    use ReadsDownloads;
    use RefreshDatabase;

    private User $admin;

    private User $writer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->admin()->create(['name' => 'Admin Utama', 'username' => 'adminutama']);
        $this->writer = User::factory()->create(['name' => 'Zaki', 'username' => 'zaki']);
        $this->actingAs($this->admin);
    }

    public function test_user_list_shows_post_counts(): void
    {
        Post::factory()->count(2)->create(['user_id' => $this->writer->id]);

        $this->get('/admin/users')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Admin/UserList')
            ->where('users.total', 2)
            ->where('users.data.0.name', 'Admin Utama')
            ->where('users.data.0.role', 'admin')
            ->where('users.data.1.name', 'Zaki')
            ->where('users.data.1.posts_count', fn ($count) => (int) $count === 2)
            ->where('users.data.1.photo_url', null)
            ->missing('users.data.1.password')
            ->where('filters.search', ''));
    }

    public function test_user_list_can_be_searched(): void
    {
        $this->get('/admin/users?search=zaki')->assertInertia(fn (Assert $page) => $page
            ->has('users.data', 1)
            ->where('users.data.0.username', 'zaki')
            ->where('filters.search', 'zaki'));

        $this->get('/admin/users?search='.str_repeat('a', 101))->assertSessionHasErrors('search');
    }

    public function test_user_posts_page_is_monitoring_for_one_user(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki']);
        Post::factory()->draft()->create(['user_id' => $this->writer->id, 'title' => 'Draf Zaki']);
        Post::factory()->create(['title' => 'Orang Lain']);

        $this->get("/admin/users/{$this->writer->id}/posts")->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Admin/UserPostList')
            ->where('owner', ['id' => $this->writer->id, 'name' => 'Zaki', 'username' => 'zaki'])
            ->where('posts.total', 2)
            ->where('stats', ['total' => 2, 'published' => 1, 'draft' => 1])
            ->where('filters', ['search' => '', 'category' => '', 'status' => ''])
            ->has('categories', 6));
    }

    public function test_user_posts_page_supports_filters(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki', 'category' => 'Bisnis', 'content' => 'a']);
        Post::factory()->draft()->create(['user_id' => $this->writer->id, 'title' => 'Draf Zaki', 'category' => 'Umum', 'content' => 'b']);
        $base = "/admin/users/{$this->writer->id}/posts";

        $this->get($base.'?status=draft')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Draf Zaki'));
        $this->get($base.'?search=terbit')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Terbit Zaki'));
        $this->get($base.'?category=Umum')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Draf Zaki'));
        $this->get($base.'?status=weird')->assertSessionHasErrors('status');
    }

    public function test_unknown_users_are_not_found(): void
    {
        $this->get('/admin/users/999999/posts')->assertNotFound();
        $this->get('/admin/users/abc/posts')->assertNotFound();
        $this->get('/admin/users/999999/posts/export')->assertNotFound();
    }

    public function test_one_users_posts_can_be_exported(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki']);
        Post::factory()->create(['title' => 'Orang Lain']);

        $response = $this->get("/admin/users/{$this->writer->id}/posts/export");

        $response->assertOk()->assertDownload();
        $this->assertStringContainsString('artikel-zaki-', (string) $response->headers->get('Content-Disposition'));

        $rows = $this->spreadsheetRows($response);

        $this->assertCount(2, $rows);
        $this->assertSame('Penulis', $rows[0][7]);
        $this->assertSame('Terbit Zaki', $rows[1][0]);
        $this->assertSame('Zaki', $rows[1][7]);
    }

    public function test_all_posts_page_lists_every_post_with_the_author(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki']);
        Post::factory()->draft()->create(['user_id' => $this->admin->id, 'title' => 'Draf Admin']);

        $this->get('/admin/posts')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Admin/PostList')
            ->where('posts.total', 2)
            ->where('posts.data.0.title', 'Draf Admin')
            ->where('posts.data.0.author', 'Admin Utama')
            ->where('posts.data.0.author_username', 'adminutama')
            ->where('posts.data.1.author', 'Zaki')
            ->where('filters', ['search' => '', 'category' => '', 'status' => ''])
            ->has('categories', 6));
    }

    public function test_all_posts_page_supports_filters(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki', 'category' => 'Bisnis', 'content' => 'a']);
        Post::factory()->draft()->create(['user_id' => $this->admin->id, 'title' => 'Draf Admin', 'category' => 'Umum', 'content' => 'b']);

        $this->get('/admin/posts?status=draft')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Draf Admin'));
        $this->get('/admin/posts?category=Bisnis')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Terbit Zaki'));
        $this->get('/admin/posts?search=admin')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('filters.search', 'admin'));
        $this->get('/admin/posts?status=weird')->assertSessionHasErrors('status');
    }

    public function test_every_post_can_be_exported(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id]);
        Post::factory()->draft()->create(['user_id' => $this->admin->id]);

        $response = $this->get('/admin/posts/export');

        $response->assertOk()->assertDownload();
        $this->assertStringContainsString('semua-artikel-', (string) $response->headers->get('Content-Disposition'));

        $rows = $this->spreadsheetRows($response);

        $this->assertCount(3, $rows);
        $this->assertSame('Penulis', $rows[0][7]);
    }

    public function test_the_admin_panel_never_changes_posts(): void
    {
        $post = Post::factory()->create(['user_id' => $this->writer->id]);

        $this->put("/dashboard/posts/{$post->id}", ['title' => 'x', 'category' => 'Umum', 'content' => 'y'])->assertForbidden();
        $this->delete("/dashboard/posts/{$post->id}")->assertForbidden();

        $this->assertDatabaseHas('posts', ['id' => $post->id, 'title' => $post->title]);
    }
}