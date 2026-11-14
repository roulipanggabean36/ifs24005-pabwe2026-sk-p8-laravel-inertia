<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

final class PublicPostTest extends TestCase
{
    use RefreshDatabase;

    public function test_home_lists_published_posts_only(): void
    {
        Post::factory()->count(2)->create();
        Post::factory()->draft()->create(['title' => 'Draf Rahasia']);

        $this->get('/')
            ->assertOk()
            ->assertDontSee('Draf Rahasia')
            ->assertInertia(fn (Assert $page) => $page
                ->component('Public/PostIndex')
                ->where('isHome', true)
                ->where('posts.total', 2)
                ->has('posts.data', 2)
                ->where('filters', ['search' => '', 'category' => ''])
                ->has('categories', 6)
                ->where('categories.0', ['value' => 'Teknologi', 'label' => 'Teknologi & Koding']));
    }

    public function test_list_items_expose_summary_fields_without_the_content(): void
    {
        $user = User::factory()->create(['name' => 'Penulis Satu']);
        Post::factory()->create([
            'user_id' => $user->id,
            'title' => 'Judul Terbit',
            'slug' => 'judul-terbit',
            'cover_image_path' => 'covers/a.jpg',
        ]);

        $this->get('/articles')->assertInertia(fn (Assert $page) => $page
            ->component('Public/PostIndex')
            ->where('isHome', false)
            ->where('posts.data.0.title', 'Judul Terbit')
            ->where('posts.data.0.slug', 'judul-terbit')
            ->where('posts.data.0.author', 'Penulis Satu')
            ->where('posts.data.0.cover_url', '/storage/covers/a.jpg')
            ->has('posts.data.0.published_at')
            ->has('posts.data.0.excerpt')
            ->missing('posts.data.0.content'));
    }

    public function test_search_filters_by_title(): void
    {
        Post::factory()->create(['title' => 'Belajar Laravel', 'content' => 'a']);
        Post::factory()->create(['title' => 'Belajar React', 'content' => 'b']);

        $this->get('/articles?search=laravel')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.data.0.title', 'Belajar Laravel')
            ->where('filters.search', 'laravel'));
    }

    public function test_search_works_on_the_home_page_too(): void
    {
        Post::factory()->create(['title' => 'Kopi Pagi', 'content' => 'a']);
        Post::factory()->create(['title' => 'Teh Sore', 'content' => 'b']);

        $this->get('/?search=kopi')->assertInertia(fn (Assert $page) => $page
            ->where('isHome', true)
            ->has('posts.data', 1)
            ->where('posts.data.0.title', 'Kopi Pagi'));
    }

    public function test_category_filter(): void
    {
        Post::factory()->category(PostCategory::Bisnis)->create();
        Post::factory()->category(PostCategory::Opini)->create();

        $this->get('/articles?category=Bisnis')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.data.0.category', 'Bisnis')
            ->where('filters.category', 'Bisnis'));
    }

    public function test_pagination_keeps_the_query_string(): void
    {
        Post::factory()->count(10)->category(PostCategory::Umum)->create();

        $this->get('/articles?category=Umum')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 9)
            ->where('posts.total', 10)
            ->where('posts.last_page', 2));

        $this->get('/articles?category=Umum&page=2')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.current_page', 2)
            ->where('posts.prev_page_url', fn ($url) => str_contains((string) $url, 'category=Umum')));
    }

    public function test_filters_are_validated(): void
    {
        $this->get('/articles?search='.str_repeat('a', 101))->assertSessionHasErrors('search');
        $this->get('/articles?category='.str_repeat('a', 51))->assertSessionHasErrors('category');
    }

    public function test_signed_in_users_can_read_the_public_pages(): void
    {
        Post::factory()->create();

        $this->actingAs(User::factory()->create())->get('/')->assertOk();
        $this->actingAs(User::factory()->admin()->create())->get('/articles')->assertOk();
    }

    public function test_a_published_article_can_be_read_by_slug(): void
    {
        $post = Post::factory()->create([
            'title' => 'Judul Publik',
            'slug' => 'judul-publik',
            'content' => '## Isi',
        ]);

        $this->get('/articles/judul-publik')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('Public/PostShow')
                ->where('post.title', 'Judul Publik')
                ->where('post.slug', 'judul-publik')
                ->where('post.content', '## Isi')
                ->where('post.author', $post->user->name)
                ->where('post.cover_url', null)
                ->has('post.published_at'));
    }

    public function test_cover_url_is_exposed_on_the_article(): void
    {
        Post::factory()->create(['slug' => 'bersampul', 'cover_image_path' => 'covers/x.jpg']);

        $this->get('/articles/bersampul')->assertInertia(fn (Assert $page) => $page
            ->where('post.cover_url', '/storage/covers/x.jpg'));
    }

    public function test_drafts_and_unknown_slugs_are_not_found(): void
    {
        Post::factory()->draft()->create(['slug' => 'draf-rahasia']);

        $this->get('/articles/draf-rahasia')->assertNotFound();
        $this->get('/articles/tidak-ada')->assertNotFound();
    }
}