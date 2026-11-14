<?php

declare(strict_types=1);

namespace App\Providers;

use App\Features\Ai\Contracts\AiClientInterface;
use App\Features\Post\Contracts\PostRepositoryInterface;
use App\Features\Post\Models\Post;
use App\Features\Post\Policies\PostPolicy;
use App\Features\Post\Repositories\PostRepository;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Lang;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;
use RuntimeException;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(PostRepositoryInterface::class, PostRepository::class);
        $this->app->bind(AiClientInterface::class, fn (): AiClientInterface => $this->makeOpenAiClient());
    }

    public function boot(): void
    {
        if (config('app.force_https')) {
            URL::forceHttps();
        }

        Gate::policy(Post::class, PostPolicy::class);

        Lang::addLines($this->indonesianValidationLines(), 'id');
    }

    private function makeOpenAiClient(): AiClientInterface
    {
        return new class implements AiClientInterface
        {
            public function complete(string $systemPrompt, string $userPrompt): string
            {
                $apiKey = config('openai.api_key');

                if (! is_string($apiKey) || $apiKey === '') {
                    throw new RuntimeException('Kunci API OpenAI belum dikonfigurasi.');
                }

                try {
                    $response = Http::withToken($apiKey)
                        ->acceptJson()
                        ->timeout((int) config('openai.timeout', 60))
                        ->post(rtrim((string) config('openai.base_url'), '/').'/chat/completions', [
                            'model' => (string) config('openai.model'),
                            'messages' => [
                                ['role' => 'system', 'content' => $systemPrompt],
                                ['role' => 'user', 'content' => $userPrompt],
                            ],
                            'response_format' => ['type' => 'json_object'],
                            'temperature' => 0.7,
                        ]);
                } catch (ConnectionException) {
                    throw new RuntimeException('Tidak dapat terhubung ke layanan AI atau waktu tunggu habis. Coba lagi.');
                }

                if ($response->failed()) {
                    throw new RuntimeException('Layanan AI mengembalikan kesalahan ('.$response->status().'). Coba lagi nanti.');
                }

                $content = $response->json('choices.0.message.content');

                if (! is_string($content) || trim($content) === '') {
                    throw new RuntimeException('Layanan AI mengembalikan respons kosong. Coba lagi.');
                }

                return $content;
            }
        };
    }

    /**
     * @return array<string, string>
     */
    private function indonesianValidationLines(): array
    {
        return [
            'validation.required' => ':attribute wajib diisi.',
            'validation.string' => ':attribute harus berupa teks.',
            'validation.integer' => ':attribute harus berupa bilangan bulat.',
            'validation.boolean' => ':attribute harus bernilai benar atau salah.',
            'validation.array' => ':attribute harus berupa daftar.',
            'validation.confirmed' => 'Konfirmasi :attribute tidak cocok.',
            'validation.unique' => ':attribute sudah digunakan.',
            'validation.in' => ':attribute yang dipilih tidak valid.',
            'validation.image' => ':attribute harus berupa gambar.',
            'validation.file' => ':attribute harus berupa berkas.',
            'validation.uploaded' => ':attribute gagal diunggah.',
            'validation.mimes' => ':attribute harus berformat: :values.',
            'validation.alpha_dash' => ':attribute hanya boleh berisi huruf, angka, strip, dan garis bawah.',
            'validation.max.string' => ':attribute maksimal :max karakter.',
            'validation.max.numeric' => ':attribute maksimal :max.',
            'validation.max.file' => ':attribute maksimal :max KB.',
            'validation.max.array' => ':attribute maksimal :max item.',
            'validation.min.string' => ':attribute minimal :min karakter.',
            'validation.min.numeric' => ':attribute minimal :min.',
            'validation.min.array' => ':attribute minimal :min item.',
            'validation.attributes.name' => 'Nama',
            'validation.attributes.username' => 'Username',
            'validation.attributes.password' => 'Kata sandi',
            'validation.attributes.title' => 'Judul',
            'validation.attributes.category' => 'Kategori',
            'validation.attributes.excerpt' => 'Ringkasan',
            'validation.attributes.content' => 'Isi',
            'validation.attributes.cover' => 'Foto sampul',
            'validation.attributes.photo' => 'Foto profil',
            'validation.attributes.file' => 'Berkas',
            'validation.attributes.topic' => 'Topik',
            'validation.attributes.count' => 'Jumlah',
            'validation.attributes.items' => 'Artikel',
            'validation.attributes.search' => 'Pencarian',
            'validation.attributes.status' => 'Status',
            'validation.attributes.is_published' => 'Status publikasi',
        ];
    }
}