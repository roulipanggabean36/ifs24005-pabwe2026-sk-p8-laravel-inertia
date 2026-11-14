<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Features\Ai\Contracts\AiClientInterface;
use RuntimeException;

final class FakeAiClient implements AiClientInterface
{
    /**
     * @var list<array{system: string, user: string}>
     */
    public array $calls = [];

    public function __construct(
        private readonly string $response = '{"articles":[]}',
        private readonly ?RuntimeException $failure = null,
    ) {}

    public function complete(string $systemPrompt, string $userPrompt): string
    {
        $this->calls[] = ['system' => $systemPrompt, 'user' => $userPrompt];

        if ($this->failure !== null) {
            throw $this->failure;
        }

        return $this->response;
    }

    public static function returning(string $response): self
    {
        return new self($response);
    }

    public static function failing(string $message): self
    {
        return new self('', new RuntimeException($message));
    }

    /**
     * @param  list<mixed>  $articles
     */
    public static function withArticles(array $articles): self
    {
        return new self((string) json_encode(['articles' => $articles], JSON_UNESCAPED_UNICODE));
    }
}