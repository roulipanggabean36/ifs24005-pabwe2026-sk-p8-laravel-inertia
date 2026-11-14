<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Enums\PostCategory;
use PHPUnit\Framework\TestCase;

final class PostCategoryTest extends TestCase
{
    public function test_values_lists_every_category(): void
    {
        $this->assertSame(
            ['Teknologi', 'Pendidikan', 'Gaya Hidup', 'Bisnis', 'Opini', 'Umum'],
            PostCategory::values(),
        );
    }

    public function test_every_case_has_a_label(): void
    {
        $expected = [
            'Teknologi' => 'Teknologi & Koding',
            'Pendidikan' => 'Pendidikan & Tutorial',
            'Gaya Hidup' => 'Gaya Hidup & Produktivitas',
            'Bisnis' => 'Bisnis & Karir',
            'Opini' => 'Opini & Pemikiran',
            'Umum' => 'Umum',
        ];

        foreach (PostCategory::cases() as $case) {
            $this->assertSame($expected[$case->value], $case->label());
        }
    }

    public function test_options_pair_value_with_label(): void
    {
        $options = PostCategory::options();

        $this->assertCount(6, $options);
        $this->assertSame(
            ['value' => 'Gaya Hidup', 'label' => 'Gaya Hidup & Produktivitas'],
            $options[2],
        );
    }

    public function test_try_from_accepts_known_values_only(): void
    {
        $this->assertSame(PostCategory::Bisnis, PostCategory::tryFrom('Bisnis'));
        $this->assertNull(PostCategory::tryFrom('Tidak Ada'));
    }
}