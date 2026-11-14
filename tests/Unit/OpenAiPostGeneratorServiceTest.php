<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Ai\Services\OpenAiPostGeneratorService;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\FakeAiClient;

final class OpenAiPostGeneratorServiceTest extends TestCase
{
    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function article(array $overrides = []): array
    {
        return array_merge([
            'title' => 'Judul',
            'category' => 'Teknologi',
            'excerpt' => 'Ringkas',
            'content' => '## Isi',
        ], $overrides);
    }

    public function test_generate_maps_articles_into_items(): void
    {
        $client = FakeAiClient::withArticles([
            $this->article(['title' => 'Satu']),
            $this->article(['title' => 'Dua', 'category' => 'Bisnis']),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('Laravel', 2);

        $this->assertCount(2, $items);
        $this->assertSame('Satu', $items[0]->title);
        $this->assertSame('Bisnis', $items[1]->category);
        $this->assertSame('Ringkas', $items[0]->excerpt);
        $this->assertSame('## Isi', $items[0]->content);
    }

    public function test_generate_sends_topic_count_and_category_list(): void
    {
        $client = FakeAiClient::withArticles([$this->article()]);

        (new OpenAiPostGeneratorService($client))->generate('  Laravel  ', 3);

        $this->assertCount(1, $client->calls);
        $this->assertStringContainsString('Buat 3 artikel blog berbeda tentang topik: Laravel', $client->calls[0]['user']);
        $this->assertStringContainsString(
            'Teknologi, Pendidikan, Gaya Hidup, Bisnis, Opini, Umum',
            $client->calls[0]['system'],
        );
    }

    public function test_generate_clamps_the_requested_count(): void
    {
        $client = FakeAiClient::withArticles([$this->article()]);
        $service = new OpenAiPostGeneratorService($client);

        $service->generate('x', 99);
        $service->generate('x', 0);

        $this->assertStringContainsString('Buat 10 artikel', $client->calls[0]['user']);
        $this->assertStringContainsString('Buat 1 artikel', $client->calls[1]['user']);
    }

    public function test_generate_accepts_a_plain_list(): void
    {
        $client = FakeAiClient::returning((string) json_encode([$this->article(['title' => 'Daftar'])]));

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 1);

        $this->assertSame('Daftar', $items[0]->title);
    }

    public function test_generate_strips_markdown_code_fences(): void
    {
        $json = json_encode(['articles' => [$this->article(['title' => 'Berpagar'])]]);
        $client = FakeAiClient::returning("```json\n".$json."\n```");

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 1);

        $this->assertSame('Berpagar', $items[0]->title);
    }

    public function test_unknown_category_falls_back_to_umum_and_match_ignores_case(): void
    {
        $client = FakeAiClient::withArticles([
            $this->article(['category' => 'Astronomi']),
            $this->article(['category' => 'teknologi']),
            $this->article(['category' => null]),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 3);

        $this->assertSame(['Umum', 'Teknologi', 'Umum'], array_map(fn ($item) => $item->category, $items));
    }

    public function test_invalid_entries_are_skipped(): void
    {
        $client = FakeAiClient::withArticles([
            'teks biasa',
            $this->article(['title' => '']),
            $this->article(['content' => '   ']),
            $this->article(['title' => 123]),
            $this->article(['title' => 'Valid']),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 5);

        $this->assertCount(1, $items);
        $this->assertSame('Valid', $items[0]->title);
    }

    public function test_result_is_limited_to_the_requested_count(): void
    {
        $client = FakeAiClient::withArticles([
            $this->article(['title' => 'A']),
            $this->article(['title' => 'B']),
            $this->article(['title' => 'C']),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 2);

        $this->assertSame(['A', 'B'], array_map(fn ($item) => $item->title, $items));
    }

    public function test_long_title_and_excerpt_are_truncated(): void
    {
        $client = FakeAiClient::withArticles([
            $this->article(['title' => str_repeat('a', 300), 'excerpt' => str_repeat('b', 1500)]),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 1);

        $this->assertSame(255, strlen($items[0]->title));
        $this->assertSame(1000, strlen($items[0]->excerpt));
    }

    public function test_missing_excerpt_becomes_empty_string(): void
    {
        $client = FakeAiClient::withArticles([
            ['title' => 'Tanpa Ringkasan', 'content' => 'isi'],
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 1);

        $this->assertSame('', $items[0]->excerpt);
    }

    public function test_invalid_json_raises_a_friendly_error(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Respons AI tidak dapat dibaca');

        (new OpenAiPostGeneratorService(FakeAiClient::returning('bukan json')))->generate('x', 1);
    }

    public function test_scalar_json_raises_a_friendly_error(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Respons AI tidak dapat dibaca');

        (new OpenAiPostGeneratorService(FakeAiClient::returning('5')))->generate('x', 1);
    }

    public function test_empty_article_list_raises_an_error(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('AI tidak menghasilkan artikel');

        (new OpenAiPostGeneratorService(FakeAiClient::withArticles([])))->generate('x', 1);
    }

    public function test_object_without_articles_key_raises_an_error(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('AI tidak menghasilkan artikel');

        (new OpenAiPostGeneratorService(FakeAiClient::returning('{"foo":"bar"}')))->generate('x', 1);
    }

    public function test_client_failure_is_propagated(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Layanan AI sedang gangguan');

        (new OpenAiPostGeneratorService(FakeAiClient::failing('Layanan AI sedang gangguan')))->generate('x', 1);
    }
}