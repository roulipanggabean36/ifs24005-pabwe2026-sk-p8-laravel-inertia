<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Models\Post;
use App\Features\Post\Services\PostService;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

final class PostServiceTest extends TestCase
{
    use RefreshDatabase;

    private PostService $service;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
        $this->service = $this->app->make(PostService::class);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function data(array $overrides = []): array
    {
        return array_merge([
            'title' => 'Judul Artikel',
            'category' => 'Umum',
            'content' => 'Isi artikel',
        ], $overrides);
    }

    public function test_create_builds_slug_excerpt_and_publication_state(): void
    {
        $user = User::factory()->create();

        $post = $this->service->create($user, $this->data([
            'title' => 'Halo Dunia',
            'content' => "## Judul\n\nIsi **tebal** artikel",
            'is_published' => true,
        ]));

        $this->assertSame('halo-dunia', $post->slug);
        $this->assertSame('Judul Isi tebal artikel', $post->excerpt);
        $this->assertTrue($post->is_published);
        $this->assertNotNull($post->published_at);
        $this->assertTrue($post->user->is($user));
    }

    public function test_create_without_publish_flag_makes_a_draft(): void
    {
        $post = $this->service->create(User::factory()->create(), $this->data());

        $this->assertFalse($post->is_published);
        $this->assertNull($post->published_at);
    }

    public function test_create_truncates_a_long_generated_excerpt(): void
    {
        $post = $this->service->create(
            User::factory()->create(),
            $this->data(['content' => str_repeat('a', 400)]),
        );

        $this->assertSame(163, strlen($post->excerpt));
        $this->assertStringEndsWith('...', $post->excerpt);
    }

    public function test_create_keeps_a_given_excerpt_trimmed(): void
    {
        $post = $this->service->create(
            User::factory()->create(),
            $this->data(['excerpt' => '  Ringkas  ']),
        );

        $this->assertSame('Ringkas', $post->excerpt);
    }

    public function test_create_uses_an_explicit_published_at(): void
    {
        $post = $this->service->create(User::factory()->create(), $this->data([
            'is_published' => true,
            'published_at' => '2026-01-02 03:04:05',
        ]));

        $this->assertSame('2026-01-02 03:04:05', $post->published_at->format('Y-m-d H:i:s'));
    }

    public function test_create_generates_unique_slugs(): void
    {
        $user = User::factory()->create();

        $slugs = [];

        foreach (range(1, 3) as $ignored) {
            $slugs[] = $this->service->create($user, $this->data(['title' => 'Sama']))->slug;
        }

        $this->assertSame(['sama', 'sama-2', 'sama-3'], $slugs);
    }

    public function test_create_handles_titles_without_slug_characters(): void
    {
        $user = User::factory()->create();

        $first = $this->service->create($user, $this->data(['title' => '!!!']));
        $second = $this->service->create($user, $this->data(['title' => '???']));

        $this->assertSame('artikel', $first->slug);
        $this->assertSame('artikel-2', $second->slug);
    }

    public function test_create_limits_the_slug_length(): void
    {
        $post = $this->service->create(
            User::factory()->create(),
            $this->data(['title' => str_repeat('a', 250)]),
        );

        $this->assertSame(200, strlen($post->slug));
    }

    public function test_create_stores_the_cover_image(): void
    {
        $post = $this->service->create(
            User::factory()->create(),
            $this->data(),
            UploadedFile::fake()->image('c.jpg'),
        );

        $this->assertStringStartsWith('covers/', (string) $post->cover_image_path);
        Storage::disk('public')->assertExists((string) $post->cover_image_path);
    }

    public function test_update_keeps_the_slug_when_the_title_is_unchanged(): void
    {
        $post = Post::factory()->create(['title' => 'Tetap', 'slug' => 'tetap-slug']);

        $updated = $this->service->update($post, $this->data(['title' => 'Tetap', 'content' => 'baru']));

        $this->assertSame('tetap-slug', $updated->slug);
        $this->assertSame('baru', $updated->content);
    }

    public function test_update_changes_the_slug_when_the_title_changes(): void
    {
        $post = Post::factory()->create(['slug' => 'lama']);

        $updated = $this->service->update($post, $this->data(['title' => 'Judul Baru']));

        $this->assertSame('judul-baru', $updated->slug);

        Post::factory()->create(['slug' => 'kembar']);
        $other = Post::factory()->create(['slug' => 'lain']);

        $this->assertSame('kembar-2', $this->service->update($other, $this->data(['title' => 'Kembar']))->slug);
    }

    public function test_update_resolves_the_excerpt_from_content(): void
    {
        $post = Post::factory()->create();

        $updated = $this->service->update($post, $this->data(['content' => 'Isi baru sekali']));

        $this->assertSame('Isi baru sekali', $updated->excerpt);
    }

    public function test_update_applies_the_publish_flag(): void
    {
        $draft = Post::factory()->draft()->create();

        $published = $this->service->update($draft, $this->data(['is_published' => true]));

        $this->assertTrue($published->is_published);
        $this->assertNotNull($published->published_at);

        $back = $this->service->update($published, $this->data(['is_published' => false]));

        $this->assertFalse($back->is_published);
        $this->assertNull($back->published_at);
    }

    public function test_update_preserves_an_existing_published_at(): void
    {
        $post = Post::factory()->create(['published_at' => '2026-01-01 00:00:00']);

        $updated = $this->service->update($post, $this->data(['is_published' => true]));

        $this->assertSame('2026-01-01', $updated->published_at->format('Y-m-d'));
    }

    public function test_update_without_the_flag_keeps_the_publication_state(): void
    {
        $post = Post::factory()->create();

        $updated = $this->service->update($post, $this->data());

        $this->assertTrue($updated->is_published);
        $this->assertNotNull($updated->published_at);
    }

    public function test_delete_removes_the_post_and_its_cover(): void
    {
        Storage::disk('public')->put('covers/a.jpg', 'x');
        $post = Post::factory()->create(['cover_image_path' => 'covers/a.jpg']);

        $this->service->delete($post);

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
        Storage::disk('public')->assertMissing('covers/a.jpg');
    }

    public function test_delete_works_without_a_cover(): void
    {
        $post = Post::factory()->create(['cover_image_path' => null]);

        $this->service->delete($post);

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
    }

    public function test_toggle_publish_flips_the_state(): void
    {
        $post = Post::factory()->draft()->create();

        $on = $this->service->togglePublish($post);

        $this->assertTrue($on->is_published);
        $this->assertNotNull($on->published_at);

        $off = $this->service->togglePublish($on);

        $this->assertFalse($off->is_published);
        $this->assertNull($off->published_at);
    }

    public function test_upload_cover_replaces_the_previous_file(): void
    {
        Storage::disk('public')->put('covers/lama.jpg', 'x');
        $post = Post::factory()->create(['cover_image_path' => 'covers/lama.jpg']);

        $updated = $this->service->uploadCover($post, UploadedFile::fake()->image('baru.jpg'));

        Storage::disk('public')->assertMissing('covers/lama.jpg');
        Storage::disk('public')->assertExists((string) $updated->cover_image_path);
        $this->assertNotSame('covers/lama.jpg', $updated->cover_image_path);
    }

    public function test_remove_cover_deletes_the_file_and_is_safe_to_repeat(): void
    {
        Storage::disk('public')->put('covers/a.jpg', 'x');
        $post = Post::factory()->create(['cover_image_path' => 'covers/a.jpg']);

        $updated = $this->service->removeCover($post);

        $this->assertNull($updated->cover_image_path);
        Storage::disk('public')->assertMissing('covers/a.jpg');
        $this->assertNull($this->service->removeCover($updated)->cover_image_path);
    }

    public function test_create_many_saves_drafts(): void
    {
        $user = User::factory()->create();

        $count = $this->service->createMany($user, [
            ['title' => 'Satu', 'category' => 'Umum', 'excerpt' => 'r', 'content' => 'isi'],
            ['title' => 'Dua', 'category' => 'Bisnis', 'content' => 'isi'],
        ]);

        $this->assertSame(2, $count);
        $this->assertSame(
            2,
            Post::query()->where('user_id', $user->id)->where('is_published', false)->count(),
        );
    }

    public function test_create_many_rolls_back_when_an_item_fails(): void
    {
        $user = User::factory()->create();

        try {
            $this->service->createMany($user, [
                ['title' => 'Valid', 'category' => 'Umum', 'content' => 'isi'],
                ['title' => 'Rusak', 'category' => null, 'content' => 'isi'],
            ]);

            $this->fail('QueryException seharusnya dilempar.');
        } catch (QueryException) {
            $this->assertSame(0, Post::query()->count());
        }
    }

    public function test_listing_helpers_delegate_to_the_repository(): void
    {
        $user = User::factory()->create();
        $published = Post::factory()->create(['user_id' => $user->id, 'slug' => 'terbit-satu']);
        Post::factory()->draft()->create(['user_id' => $user->id]);

        $this->assertSame(1, $this->service->listPublic(null, null)->total());
        $this->assertTrue($this->service->findPublished('terbit-satu')->is($published));
        $this->assertNull($this->service->findPublished('tidak-ada'));
        $this->assertSame(2, $this->service->listForUser($user->id, null, null, null)->total());
        $this->assertSame(2, $this->service->listAll(null, null, null)->total());
        $this->assertSame(
            ['total' => 2, 'published' => 1, 'draft' => 1],
            $this->service->statsForUser($user->id),
        );
        $this->assertCount(2, $this->service->exportForUser($user->id));
        $this->assertCount(2, $this->service->exportAll());
    }
}