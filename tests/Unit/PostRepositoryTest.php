<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Features\Post\Repositories\PostRepository;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class PostRepositoryTest extends TestCase
{
    use RefreshDatabase;

    private PostRepository $repository;

    protected function setUp(): void
    {
        parent::setUp();

        $this->repository = new PostRepository();
    }

    /**
     * @param  iterable<int, Post>  $posts
     * @return list<string>
     */
    private function titles(iterable $posts): array
    {
        return collect($posts)->pluck('title')->values()->all();
    }

    public function test_public_listing_has_only_published_posts_newest_first(): void
    {
        Post::factory()->create(['title' => 'Lama', 'published_at' => now()->subDays(5)]);
        Post::factory()->create(['title' => 'Baru', 'published_at' => now()]);
        Post::factory()->draft()->create(['title' => 'Draf']);

        $page = $this->repository->paginatePublic(null, null);

        $this->assertSame(2, $page->total());
        $this->assertSame(['Baru', 'Lama'], $this->titles($page->items()));
        $this->assertTrue($page->items()[0]->relationLoaded('user'));
    }

    public function test_public_listing_respects_per_page(): void
    {
        Post::factory()->count(3)->create();

        $page = $this->repository->paginatePublic(null, null, 2);

        $this->assertCount(2, $page->items());
        $this->assertSame(2, $page->lastPage());
    }

    public function test_search_matches_title_case_insensitively(): void
    {
        Post::factory()->create(['title' => 'Belajar Laravel', 'content' => 'isi satu']);
        Post::factory()->create(['title' => 'Belajar React', 'content' => 'isi dua']);

        $page = $this->repository->paginatePublic('laravel', null);

        $this->assertSame(['Belajar Laravel'], $this->titles($page->items()));
    }

    public function test_search_matches_content(): void
    {
        Post::factory()->create(['title' => 'Judul A', 'content' => 'Membahas Eloquent ORM']);
        Post::factory()->create(['title' => 'Judul B', 'content' => 'Hal lainnya']);

        $page = $this->repository->paginatePublic('eloquent', null);

        $this->assertSame(['Judul A'], $this->titles($page->items()));
    }

    public function test_search_treats_percent_literally(): void
    {
        Post::factory()->create(['title' => 'Diskon 50% hari ini', 'content' => 'a']);
        Post::factory()->create(['title' => 'Diskon 500 rupiah', 'content' => 'b']);

        $page = $this->repository->paginatePublic('50%', null);

        $this->assertSame(['Diskon 50% hari ini'], $this->titles($page->items()));
    }

    public function test_search_treats_underscore_literally(): void
    {
        Post::factory()->create(['title' => 'kode_unik', 'content' => 'a']);
        Post::factory()->create(['title' => 'kodeXunik', 'content' => 'b']);

        $page = $this->repository->paginatePublic('kode_unik', null);

        $this->assertSame(['kode_unik'], $this->titles($page->items()));
    }

    public function test_blank_search_is_ignored(): void
    {
        Post::factory()->count(2)->create();

        $this->assertSame(2, $this->repository->paginatePublic('   ', null)->total());
        $this->assertSame(2, $this->repository->paginatePublic(null, null)->total());
    }

    public function test_category_filter_accepts_valid_and_ignores_unknown_values(): void
    {
        Post::factory()->category(PostCategory::Bisnis)->create();
        Post::factory()->category(PostCategory::Opini)->create();

        $bisnis = $this->repository->paginatePublic(null, 'Bisnis');

        $this->assertSame(1, $bisnis->total());
        $this->assertSame('Bisnis', $bisnis->items()[0]->category);
        $this->assertSame(2, $this->repository->paginatePublic(null, 'Tidak Ada')->total());
    }

    public function test_find_published_by_slug(): void
    {
        $published = Post::factory()->create(['slug' => 'terbit']);
        Post::factory()->draft()->create(['slug' => 'draf']);

        $found = $this->repository->findPublishedBySlug('terbit');

        $this->assertNotNull($found);
        $this->assertTrue($found->is($published));
        $this->assertTrue($found->relationLoaded('user'));
        $this->assertNull($this->repository->findPublishedBySlug('draf'));
        $this->assertNull($this->repository->findPublishedBySlug('tidak-ada'));
    }

    public function test_user_listing_contains_only_own_posts_newest_first(): void
    {
        $mine = User::factory()->create();
        $other = User::factory()->create();

        Post::factory()->count(2)->create(['user_id' => $mine->id]);
        Post::factory()->draft()->create(['user_id' => $mine->id, 'title' => 'Draf Terbaru']);
        Post::factory()->create(['user_id' => $other->id]);

        $page = $this->repository->paginateForUser($mine->id, null, null, null);

        $this->assertSame(3, $page->total());
        $this->assertSame('Draf Terbaru', $page->items()[0]->title);
    }

    public function test_user_listing_status_filter(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->draft()->create(['user_id' => $user->id]);

        $this->assertSame(2, $this->repository->paginateForUser($user->id, null, null, 'published')->total());
        $this->assertSame(1, $this->repository->paginateForUser($user->id, null, null, 'draft')->total());
        $this->assertSame(3, $this->repository->paginateForUser($user->id, null, null, 'weird')->total());
    }

    public function test_user_listing_supports_search_and_category(): void
    {
        $user = User::factory()->create();
        Post::factory()->category(PostCategory::Teknologi)->create(['user_id' => $user->id, 'title' => 'Tentang PHP', 'content' => 'x']);
        Post::factory()->category(PostCategory::Umum)->create(['user_id' => $user->id, 'title' => 'Tentang Kopi', 'content' => 'y']);

        $page = $this->repository->paginateForUser($user->id, 'tentang', 'Teknologi', null);

        $this->assertSame(['Tentang PHP'], $this->titles($page->items()));
    }

    public function test_all_listing_includes_drafts_and_loads_author(): void
    {
        Post::factory()->create();
        Post::factory()->draft()->create();

        $page = $this->repository->paginateAll(null, null, null);

        $this->assertSame(2, $page->total());
        $this->assertTrue($page->items()[0]->relationLoaded('user'));
        $this->assertSame(1, $this->repository->paginateAll(null, null, 'draft')->total());
        $this->assertSame(1, $this->repository->paginateAll(null, null, 'published')->total());
    }

    public function test_stats_for_user(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->draft()->create(['user_id' => $user->id]);
        Post::factory()->create();

        $this->assertSame(
            ['total' => 3, 'published' => 2, 'draft' => 1],
            $this->repository->statsForUser($user->id),
        );

        $empty = User::factory()->create();

        $this->assertSame(
            ['total' => 0, 'published' => 0, 'draft' => 0],
            $this->repository->statsForUser($empty->id),
        );
    }

    public function test_export_returns_all_or_per_user_ordered_by_id(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->create();

        $all = $this->repository->forExport();

        $this->assertCount(3, $all);
        $this->assertTrue($all->first()->relationLoaded('user'));
        $this->assertTrue($all->first()->id < $all->last()->id);
        $this->assertCount(2, $this->repository->forExport($user->id));
    }

    public function test_create_update_and_delete(): void
    {
        $user = User::factory()->create();

        $post = $this->repository->create([
            'user_id' => $user->id,
            'title' => 'Judul',
            'slug' => 'judul',
            'category' => 'Umum',
            'excerpt' => 'ringkas',
            'content' => 'isi',
            'is_published' => false,
            'published_at' => null,
        ]);

        $this->assertDatabaseHas('posts', ['slug' => 'judul']);

        $updated = $this->repository->update($post, ['title' => 'Judul Baru']);

        $this->assertSame('Judul Baru', $updated->title);
        $this->assertDatabaseHas('posts', ['id' => $post->id, 'title' => 'Judul Baru']);

        $this->repository->delete($post);

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
    }

    public function test_slug_exists_can_ignore_a_post(): void
    {
        $post = Post::factory()->create(['slug' => 'sama']);

        $this->assertTrue($this->repository->slugExists('sama'));
        $this->assertFalse($this->repository->slugExists('sama', $post->id));
        $this->assertTrue($this->repository->slugExists('sama', $post->id + 1));
        $this->assertFalse($this->repository->slugExists('lain'));
    }
}