<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Ai\Contracts\AiClientInterface;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\FakeAiClient;
use Tests\TestCase;

final class AiPostTest extends TestCase
{
    use RefreshDatabase;

    private User $member;

    protected function setUp(): void
    {
        parent::setUp();

        $this->member = User::factory()->create();
        $this->actingAs($this->member);
    }

    private function fakeAi(AiClientInterface $client): void
    {
        $this->app->instance(AiClientInterface::class, $client);
    }

    public function test_generate_returns_articles_without_saving_them(): void
    {
        $fake = FakeAiClient::withArticles([
            ['title' => 'Artikel AI Satu', 'category' => 'Teknologi', 'excerpt' => 'Ringkas', 'content' => '## Isi satu'],
            ['title' => 'Artikel AI Dua', 'category' => 'astronomi', 'excerpt' => '', 'content' => 'Isi dua'],
        ]);
        $this->fakeAi($fake);

        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'Laravel', 'count' => 2])
            ->assertOk()
            ->assertJsonCount(2, 'items')
            ->assertJsonPath('items.0.title', 'Artikel AI Satu')
            ->assertJsonPath('items.1.category', 'Umum');

        $this->assertDatabaseCount('posts', 0);
        $this->assertCount(1, $fake->calls);
        $this->assertStringContainsString('Laravel', $fake->calls[0]['user']);
    }

    public function test_generate_accepts_the_boundary_counts(): void
    {
        $this->fakeAi(FakeAiClient::withArticles([
            ['title' => 'A', 'category' => 'Umum', 'content' => 'isi'],
        ]));

        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'x', 'count' => 1])->assertOk();
        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'x', 'count' => 10])->assertOk();
    }

    public function test_generate_shows_friendly_errors_from_the_ai(): void
    {
        $this->fakeAi(FakeAiClient::failing('Layanan AI sedang gangguan'));

        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'Laravel', 'count' => 2])
            ->assertStatus(422)
            ->assertExactJson(['message' => 'Layanan AI sedang gangguan']);

        $this->fakeAi(FakeAiClient::returning('bukan json'));

        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'Laravel', 'count' => 2])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Respons AI tidak dapat dibaca. Silakan coba lagi.');
    }

    public function test_generate_validates_topic_and_count(): void
    {
        $fake = new FakeAiClient();
        $this->fakeAi($fake);
        $url = '/dashboard/posts/ai-generate';

        $this->postJson($url, [])->assertJsonValidationErrors(['topic', 'count']);
        $this->postJson($url, ['topic' => str_repeat('a', 201), 'count' => 2])->assertJsonValidationErrors('topic');

        foreach ([0, 11, 'abc', 2.5] as $count) {
            $this->postJson($url, ['topic' => 'Laravel', 'count' => $count])->assertJsonValidationErrors('count');
        }

        $this->assertCount(0, $fake->calls);
    }

    public function test_save_stores_the_selected_articles_as_drafts(): void
    {
        $this->post('/dashboard/posts/ai-save', ['items' => [
            ['title' => 'AI Satu', 'category' => 'Teknologi', 'excerpt' => 'Ringkas', 'content' => 'Isi satu'],
            ['title' => 'AI Dua', 'category' => 'Bisnis', 'content' => 'Isi dua'],
        ]])
            ->assertRedirect(route('dashboard.posts.index'))
            ->assertSessionHas('success', '2 artikel hasil AI disimpan sebagai draf.');

        $this->assertSame(2, $this->member->posts()->where('is_published', false)->count());
        $this->assertDatabaseHas('posts', ['slug' => 'ai-satu', 'excerpt' => 'Ringkas']);
        $this->assertDatabaseHas('posts', ['slug' => 'ai-dua', 'excerpt' => 'Isi dua']);
    }

    public function test_save_validates_the_items(): void
    {
        $item = ['title' => 'AI', 'category' => 'Umum', 'content' => 'isi'];

        $this->post('/dashboard/posts/ai-save', [])->assertSessionHasErrors('items');
        $this->post('/dashboard/posts/ai-save', ['items' => []])->assertSessionHasErrors('items');
        $this->post('/dashboard/posts/ai-save', ['items' => array_fill(0, 11, $item)])->assertSessionHasErrors('items');
        $this->post('/dashboard/posts/ai-save', ['items' => [['category' => 'Umum', 'content' => 'isi']]])
            ->assertSessionHasErrors('items.0.title');
        $this->post('/dashboard/posts/ai-save', ['items' => [array_merge($item, ['category' => 'Astronomi'])]])
            ->assertSessionHasErrors('items.0.category');
        $this->post('/dashboard/posts/ai-save', ['items' => [['title' => 'AI', 'category' => 'Umum']]])
            ->assertSessionHasErrors('items.0.content');

        $this->assertSame(0, Post::query()->count());
    }
}