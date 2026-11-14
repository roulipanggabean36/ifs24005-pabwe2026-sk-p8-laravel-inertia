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