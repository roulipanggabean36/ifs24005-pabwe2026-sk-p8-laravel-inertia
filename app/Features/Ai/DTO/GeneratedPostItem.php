<?php

declare(strict_types=1);

namespace App\Features\Ai\DTO;

final readonly class GeneratedPostItem
{
    public function __construct(
        public string $title,
        public string $category,
        public string $excerpt,
        public string $content,
    ) {}

    /**
     * @return array{title: string, category: string, excerpt: string, content: string}
     */
    public function toArray(): array
    {
        return [
            'title' => $this->title,
            'category' => $this->category,
            'excerpt' => $this->excerpt,
            'content' => $this->content,
        ];
    }
}