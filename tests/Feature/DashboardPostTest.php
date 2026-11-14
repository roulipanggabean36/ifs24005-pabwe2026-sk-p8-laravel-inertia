<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

final class DashboardPostTest extends TestCase
{
    use RefreshDatabase;

    private User $member;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
        $this->member = User::factory()->create();
        $this->actingAs($this->member);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function payload(array $overrides = []): array
    {
        return array_merge([
            'title' => 'Artikel Baru',
            'category' => 'Umum',
            'content' => 'Isi artikel baru',
        ], $overrides);
    }

    public function test_index_lists_only_own_posts_with_stats(): void
    {
        Post::factory()->count(2)->create(['user_id' => $this->member->id]);
        Post::factory()->draft()->create(['user_id' => $this->member->id]);
        Post::factory()->create();

        $this->get('/dashboard/posts')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Post/Index')
            ->where('posts.total', 3)
            ->has('posts.data', 3)
            ->where('stats', ['total' => 3, 'published' => 2, 'draft' => 1])
            ->where('filters', ['search' => '', 'category' => '', 'status' => ''])
            ->has('categories', 6)
            ->where('aiMax', 10));
    }

    public function test_index_items_expose_the_fields_the_ui_needs(): void
    {
        Post::factory()->create([
            'user_id' => $this->member->id,
            'title' => 'Judul Saya',
            'cover_image_path' => 'covers/a.jpg',
        ]);

        $this->get('/dashboard/posts')->assertInertia(fn (Assert $page) => $page
            ->where('posts.data.0.title', 'Judul Saya')
            ->where('posts.data.0.cover_url', '/storage/covers/a.jpg')
            ->has('posts.data.0.slug')
            ->has('posts.data.0.content')
            ->has('posts.data.0.is_published')
            ->has('posts.data.0.created_at'));
    }

    public function test_index_supports_search_category_and_status_filters(): void
    {
        Post::factory()->category(PostCategory::Bisnis)->create([
            'user_id' => $this->member->id, 'title' => 'Strategi Bisnis', 'content' => 'a',
        ]);
        Post::factory()->category(PostCategory::Umum)->draft()->create([
            'user_id' => $this->member->id, 'title' => 'Catatan Harian', 'content' => 'b',
        ]);

        $this->get('/dashboard/posts?search=strategi')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.data.0.title', 'Strategi Bisnis')
            ->where('filters.search', 'strategi'));

        $this->get('/dashboard/posts?category=Umum')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.data.0.title', 'Catatan Harian'));

        $this->get('/dashboard/posts?status=draft')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.data.0.title', 'Catatan Harian')
            ->where('filters.status', 'draft'));

        $this->get('/dashboard/posts?status=published')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.data.0.title', 'Strategi Bisnis'));
    }

    public function test_index_paginates_ten_per_page(): void
    {
        Post::factory()->count(11)->create(['user_id' => $this->member->id]);

        $this->get('/dashboard/posts')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 10)
            ->where('posts.last_page', 2));

        $this->get('/dashboard/posts?page=2')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.current_page', 2));
    }

    public function test_index_validates_the_filters(): void
    {
        $this->get('/dashboard/posts?status=weird')->assertSessionHasErrors('status');
        $this->get('/dashboard/posts?search='.str_repeat('a', 101))->assertSessionHasErrors('search');
        $this->get('/dashboard/posts?category='.str_repeat('a', 51))->assertSessionHasErrors('category');
    }

    public function test_show_renders_an_owned_post(): void
    {
        $post = Post::factory()->create([
            'user_id' => $this->member->id,
            'title' => 'Detail Saya',
            'content' => '## Isi',
        ]);

        $this->get("/dashboard/posts/{$post->id}")->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Post/Show')
            ->where('post.id', $post->id)
            ->where('post.title', 'Detail Saya')
            ->where('post.content', '## Isi')
            ->has('categories', 6));
    }

    public function test_store_creates_a_draft_by_default(): void
    {
        $this->post('/dashboard/posts', $this->payload())
            ->assertRedirect(route('dashboard.posts.index'))
            ->assertSessionHas('success', 'Artikel berhasil dibuat.');

        $post = Post::query()->firstOrFail();

        $this->assertSame($this->member->id, $post->user_id);
        $this->assertSame('artikel-baru', $post->slug);
        $this->assertFalse($post->is_published);
        $this->assertNull($post->published_at);
        $this->assertSame('Isi artikel baru', $post->excerpt);
    }

    public function test_store_can_publish_with_a_custom_excerpt(): void
    {
        $this->post('/dashboard/posts', $this->payload(['is_published' => 1, 'excerpt' => 'Ringkasan saya']))
            ->assertSessionHasNoErrors();

        $post = Post::query()->firstOrFail();

        $this->assertTrue($post->is_published);
        $this->assertNotNull($post->published_at);
        $this->assertSame('Ringkasan saya', $post->excerpt);
    }

    public function test_store_saves_an_uploaded_cover(): void
    {
        $this->post('/dashboard/posts', $this->payload([
            'cover' => UploadedFile::fake()->image('sampul.jpg', 640, 360),
        ]))->assertSessionHasNoErrors();

        $path = (string) Post::query()->firstOrFail()->cover_image_path;

        $this->assertStringStartsWith('covers/', $path);
        Storage::disk('public')->assertExists($path);
    }

    public function test_store_validates_the_input(): void
    {
        $this->post('/dashboard/posts', [])->assertSessionHasErrors([
            'title' => 'Judul wajib diisi.',
            'category',
            'content',
        ]);

        $this->post('/dashboard/posts', $this->payload(['category' => 'Astronomi']))->assertSessionHasErrors('category');
        $this->post('/dashboard/posts', $this->payload(['excerpt' => str_repeat('a', 1001)]))->assertSessionHasErrors('excerpt');
        $this->post('/dashboard/posts', $this->payload(['title' => str_repeat('a', 256)]))->assertSessionHasErrors('title');
        $this->post('/dashboard/posts', $this->payload(['is_published' => 'mungkin']))->assertSessionHasErrors('is_published');

        $this->assertDatabaseCount('posts', 0);
    }

    public function test_store_rejects_invalid_covers(): void
    {
        foreach ([
            UploadedFile::fake()->create('dokumen.pdf', 10, 'application/pdf'),
            UploadedFile::fake()->image('animasi.gif'),
            UploadedFile::fake()->image('besar.jpg')->size(3000),
        ] as $file) {
            $this->post('/dashboard/posts', $this->payload(['cover' => $file]))->assertSessionHasErrors('cover');
        }

        $this->assertDatabaseCount('posts', 0);
    }

    public function test_update_changes_an_owned_post(): void
    {
        $post = Post::factory()->create(['user_id' => $this->member->id, 'title' => 'Lama', 'slug' => 'lama']);

        $this->from('/dashboard/posts')
            ->put("/dashboard/posts/{$post->id}", $this->payload(['title' => 'Judul Diperbarui', 'content' => 'Isi baru']))
            ->assertRedirect('/dashboard/posts')
            ->assertSessionHas('success', 'Artikel berhasil diperbarui.');

        $post->refresh();

        $this->assertSame('Judul Diperbarui', $post->title);
        $this->assertSame('judul-diperbarui', $post->slug);
        $this->assertSame('Isi baru', $post->content);
    }

    public function test_update_can_unpublish_a_post(): void
    {
        $post = Post::factory()->create(['user_id' => $this->member->id]);

        $this->put("/dashboard/posts/{$post->id}", $this->payload(['is_published' => 0]))
            ->assertSessionHasNoErrors();

        $post->refresh();

        $this->assertFalse($post->is_published);
        $this->assertNull($post->published_at);
    }

    public function test_update_validates_the_input(): void
    {
        $post = Post::factory()->create(['user_id' => $this->member->id, 'title' => 'Tetap']);

        $this->put("/dashboard/posts/{$post->id}", $this->payload(['title' => '']))
            ->assertSessionHasErrors('title');
        $this->put("/dashboard/posts/{$post->id}", $this->payload(['category' => 'Astronomi']))
            ->assertSessionHasErrors('category');

        $this->assertSame('Tetap', $post->refresh()->title);
    }

    public function test_destroy_deletes_the_post_and_its_cover(): void
    {
        Storage::disk('public')->put('covers/a.jpg', 'x');
        $post = Post::factory()->create(['user_id' => $this->member->id, 'cover_image_path' => 'covers/a.jpg']);

        $this->delete("/dashboard/posts/{$post->id}")
            ->assertRedirect(route('dashboard.posts.index'))
            ->assertSessionHas('success', 'Artikel berhasil dihapus.');

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
        Storage::disk('public')->assertMissing('covers/a.jpg');
    }

    public function test_publish_toggles_between_draft_and_published(): void
    {
        $post = Post::factory()->draft()->create(['user_id' => $this->member->id]);

        $this->from('/dashboard/posts')
            ->patch("/dashboard/posts/{$post->id}/publish")
            ->assertRedirect('/dashboard/posts')
            ->assertSessionHas('success', 'Artikel dipublikasikan.');

        $this->assertTrue($post->refresh()->is_published);
        $this->assertNotNull($post->published_at);

        $this->from('/dashboard/posts')
            ->patch("/dashboard/posts/{$post->id}/publish")
            ->assertSessionHas('success', 'Artikel dijadikan draf.');

        $this->assertFalse($post->refresh()->is_published);
        $this->assertNull($post->published_at);
    }

    public function test_a_cover_can_be_uploaded_and_replaced(): void
    {
        $post = Post::factory()->create(['user_id' => $this->member->id, 'cover_image_path' => null]);

        $this->from('/dashboard/posts')
            ->post("/dashboard/posts/{$post->id}/cover", ['cover' => UploadedFile::fake()->image('satu.jpg')])
            ->assertRedirect('/dashboard/posts')
            ->assertSessionHas('success', 'Foto sampul berhasil diunggah.');

        $first = (string) $post->refresh()->cover_image_path;

        $this->assertStringStartsWith('covers/', $first);
        Storage::disk('public')->assertExists($first);

        $this->post("/dashboard/posts/{$post->id}/cover", ['cover' => UploadedFile::fake()->image('dua.png')]);

        $second = (string) $post->refresh()->cover_image_path;

        Storage::disk('public')->assertMissing($first);
        Storage::disk('public')->assertExists($second);
    }

    public function test_cover_upload_validates_the_file(): void
    {
        $post = Post::factory()->create(['user_id' => $this->member->id]);
        $url = "/dashboard/posts/{$post->id}/cover";

        $this->post($url, [])->assertSessionHasErrors('cover');

        foreach ([
            UploadedFile::fake()->create('dokumen.pdf', 10, 'application/pdf'),
            UploadedFile::fake()->image('animasi.gif'),
            UploadedFile::fake()->image('besar.jpg')->size(3000),
        ] as $file) {
            $this->post($url, ['cover' => $file])->assertSessionHasErrors('cover');
        }

        $this->assertNull($post->refresh()->cover_image_path);
    }

    public function test_a_cover_can_be_removed(): void
    {
        Storage::disk('public')->put('covers/a.jpg', 'x');
        $post = Post::factory()->create(['user_id' => $this->member->id, 'cover_image_path' => 'covers/a.jpg']);

        $this->from('/dashboard/posts')
            ->delete("/dashboard/posts/{$post->id}/cover")
            ->assertRedirect('/dashboard/posts')
            ->assertSessionHas('success', 'Foto sampul berhasil dihapus.');

        $this->assertNull($post->refresh()->cover_image_path);
        Storage::disk('public')->assertMissing('covers/a.jpg');
    }
}