# fase-5a3.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path 'tests/Support/FakeAiClient.php')) {
  Write-Host "GAGAL: jalankan fase-5a.ps1 dulu." -ForegroundColor Red
  exit 1
}

W 'tests/Unit/OpenAiPostGeneratorServiceTest.php' @'
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
'@

W 'tests/Unit/AppServiceProviderTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Ai\Contracts\AiClientInterface;
use App\Features\Ai\Services\OpenAiPostGeneratorService;
use App\Features\Post\Contracts\PostRepositoryInterface;
use App\Features\Post\Models\Post;
use App\Features\Post\Policies\PostPolicy;
use App\Features\Post\Repositories\PostRepository;
use App\Providers\AppServiceProvider;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

final class AppServiceProviderTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Http::preventStrayRequests();
    }

    public function test_repository_interface_is_bound(): void
    {
        $this->assertInstanceOf(PostRepository::class, $this->app->make(PostRepositoryInterface::class));
    }

    public function test_ai_client_and_generator_can_be_resolved(): void
    {
        $this->assertInstanceOf(AiClientInterface::class, $this->app->make(AiClientInterface::class));
        $this->assertInstanceOf(OpenAiPostGeneratorService::class, $this->app->make(OpenAiPostGeneratorService::class));
    }

    public function test_post_policy_is_registered(): void
    {
        $this->assertInstanceOf(PostPolicy::class, Gate::getPolicyFor(Post::class));
    }

    public function test_validation_messages_are_in_indonesian(): void
    {
        $this->app->setLocale('id');

        $this->assertSame('Judul wajib diisi.', __('validation.required', ['attribute' => 'Judul']));
        $this->assertSame('Judul maksimal 255 karakter.', __('validation.max.string', ['attribute' => 'Judul', 'max' => 255]));
        $this->assertSame('Judul', __('validation.attributes.title'));
    }

    public function test_https_is_forced_when_enabled(): void
    {
        config(['app.force_https' => true]);

        (new AppServiceProvider($this->app))->boot();

        $this->assertStringStartsWith('https://', url('/artikel'));
    }

    public function test_https_is_not_forced_when_disabled(): void
    {
        config(['app.force_https' => false]);

        (new AppServiceProvider($this->app))->boot();

        $this->assertStringStartsWith('http://', url('/artikel'));
    }

    public function test_openai_client_returns_the_message_content(): void
    {
        config([
            'openai.api_key' => 'sk-test',
            'openai.base_url' => 'https://api.openai.test/v1/',
            'openai.model' => 'gpt-test',
        ]);

        Http::fake([
            'api.openai.test/*' => Http::response(
                ['choices' => [['message' => ['content' => '{"articles":[]}']]]],
                200,
            ),
        ]);

        $content = $this->app->make(AiClientInterface::class)->complete('sistem', 'pengguna');

        $this->assertSame('{"articles":[]}', $content);

        Http::assertSent(function (Request $request): bool {
            return $request->url() === 'https://api.openai.test/v1/chat/completions'
                && $request->hasHeader('Authorization', 'Bearer sk-test')
                && $request['model'] === 'gpt-test'
                && $request['messages'][0]['role'] === 'system'
                && $request['messages'][0]['content'] === 'sistem'
                && $request['messages'][1]['content'] === 'pengguna';
        });
    }

    public function test_openai_client_requires_an_api_key(): void
    {
        foreach (['', null] as $key) {
            config(['openai.api_key' => $key]);

            try {
                $this->app->make(AiClientInterface::class)->complete('a', 'b');
                $this->fail('RuntimeException seharusnya dilempar.');
            } catch (RuntimeException $exception) {
                $this->assertSame('Kunci API OpenAI belum dikonfigurasi.', $exception->getMessage());
            }
        }
    }

    public function test_openai_client_reports_connection_problems(): void
    {
        config(['openai.api_key' => 'sk-test']);
        Http::fake(fn () => throw new ConnectionException('timeout'));

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Tidak dapat terhubung ke layanan AI');

        $this->app->make(AiClientInterface::class)->complete('a', 'b');
    }

    public function test_openai_client_reports_http_errors(): void
    {
        config(['openai.api_key' => 'sk-test']);
        Http::fake(['*' => Http::response('error', 500)]);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('(500)');

        $this->app->make(AiClientInterface::class)->complete('a', 'b');
    }

    public function test_openai_client_rejects_empty_content(): void
    {
        config(['openai.api_key' => 'sk-test']);

        foreach ([
            ['choices' => [['message' => ['content' => '']]]],
            [],
        ] as $payload) {
            Http::fake(['*' => Http::response($payload, 200)]);

            try {
                $this->app->make(AiClientInterface::class)->complete('a', 'b');
                $this->fail('RuntimeException seharusnya dilempar.');
            } catch (RuntimeException $exception) {
                $this->assertStringContainsString('respons kosong', $exception->getMessage());
            }
        }
    }
}
'@

# Lint seluruh file PHP di tests/
$bad = 0
Get-ChildItem tests -Recurse -Filter *.php | ForEach-Object {
  php -l $_.FullName | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: sintaks PHP salah di $($_.FullName)" -ForegroundColor Red
    php -l $_.FullName
    $bad++
  }
}
if ($bad -gt 0) { exit 1 }
Write-Host "Lint PHP: semua file test valid." -ForegroundColor Green

Write-Host ""
Write-Host "FASE 5a SELESAI." -ForegroundColor Green