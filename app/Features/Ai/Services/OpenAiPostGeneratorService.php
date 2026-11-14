<?php

declare(strict_types=1);

namespace App\Features\Ai\Services;

use App\Features\Ai\Contracts\AiClientInterface;
use App\Features\Ai\DTO\GeneratedPostItem;
use App\Features\Post\Enums\PostCategory;
use Illuminate\Support\Str;
use RuntimeException;

class OpenAiPostGeneratorService
{
    public const MAX_COUNT = 10;

    public function __construct(private readonly AiClientInterface $client) {}

    /**
     * @return list<GeneratedPostItem>
     *
     * @throws RuntimeException
     */
    public function generate(string $topic, int $count): array
    {
        $count = max(1, min(self::MAX_COUNT, $count));

        $raw = $this->client->complete(
            $this->systemPrompt(),
            sprintf('Buat %d artikel blog berbeda tentang topik: %s', $count, trim($topic)),
        );

        return $this->parse($raw, $count);
    }

    private function systemPrompt(): string
    {
        return sprintf(
            'Anda adalah penulis blog profesional berbahasa Indonesia. '
            .'Balas HANYA dengan satu objek JSON valid, tanpa teks lain dan tanpa pembungkus kode, '
            .'dengan bentuk: {"articles":[{"title":"...","category":"...","excerpt":"...","content":"..."}]}. '
            .'Nilai category harus salah satu dari: %s. '
            .'Nilai excerpt berisi 1-2 kalimat pemikat pembaca. '
            .'Nilai content berisi artikel lengkap berformat Markdown (subjudul ##, paragraf, daftar bila perlu).',
            implode(', ', PostCategory::values()),
        );
    }

    /**
     * @return list<GeneratedPostItem>
     */
    private function parse(string $raw, int $count): array
    {
        $decoded = json_decode($this->stripFences($raw), true);

        if (! is_array($decoded)) {
            throw new RuntimeException('Respons AI tidak dapat dibaca. Silakan coba lagi.');
        }

        $list = array_is_list($decoded) ? $decoded : ($decoded['articles'] ?? null);
        $list = is_array($list) ? $list : [];

        $items = [];

        foreach ($list as $entry) {
            $item = is_array($entry) ? $this->toItem($entry) : null;

            if ($item !== null) {
                $items[] = $item;
            }

            if (count($items) === $count) {
                break;
            }
        }

        if ($items === []) {
            throw new RuntimeException('AI tidak menghasilkan artikel yang dapat digunakan. Coba ubah topik Anda.');
        }

        return $items;
    }

    /**
     * @param  array<array-key, mixed>  $entry
     */
    private function toItem(array $entry): ?GeneratedPostItem
    {
        $title = $this->text($entry['title'] ?? null);
        $content = $this->text($entry['content'] ?? null);

        if ($title === '' || $content === '') {
            return null;
        }

        return new GeneratedPostItem(
            title: Str::limit($title, 255, ''),
            category: $this->category($this->text($entry['category'] ?? null)),
            excerpt: Str::limit($this->text($entry['excerpt'] ?? null), 1000, ''),
            content: $content,
        );
    }

    private function category(string $input): string
    {
        foreach (PostCategory::cases() as $category) {
            if (mb_strtolower($category->value) === mb_strtolower($input)) {
                return $category->value;
            }
        }

        return PostCategory::Umum->value;
    }

    private function text(mixed $value): string
    {
        return is_string($value) ? trim($value) : '';
    }

    private function stripFences(string $raw): string
    {
        return trim((string) preg_replace('/^```(?:json)?\s*|\s*```$/i', '', trim($raw)));
    }
}