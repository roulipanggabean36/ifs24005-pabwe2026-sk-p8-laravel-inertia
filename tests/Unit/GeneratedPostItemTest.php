<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Ai\DTO\GeneratedPostItem;
use PHPUnit\Framework\TestCase;

final class GeneratedPostItemTest extends TestCase
{
    public function test_to_array_exposes_all_fields(): void
    {
        $item = new GeneratedPostItem('Judul', 'Teknologi', 'Ringkasan', '## Isi');

        $this->assertSame('Judul', $item->title);
        $this->assertSame([
            'title' => 'Judul',
            'category' => 'Teknologi',
            'excerpt' => 'Ringkasan',
            'content' => '## Isi',
        ], $item->toArray());
    }
}