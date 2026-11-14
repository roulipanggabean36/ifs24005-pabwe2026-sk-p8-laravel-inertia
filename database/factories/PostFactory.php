<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Post>
 */
class PostFactory extends Factory
{
    protected $model = Post::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $title = rtrim(fake()->sentence(6), '.');

        return [
            'user_id' => User::factory(),
            'title' => $title,
            'slug' => Str::slug($title).'-'.fake()->unique()->numberBetween(1000, 9999999),
            'category' => fake()->randomElement(PostCategory::values()),
            'excerpt' => fake()->sentence(12),
            'content' => '## '.fake()->sentence(4)."\n\n".fake()->paragraph(4)."\n\n".fake()->paragraph(3),
            'cover_image_path' => null,
            'is_published' => true,
            'published_at' => now(),
        ];
    }

    public function published(): static
    {
        return $this->state(fn (): array => [
            'is_published' => true,
            'published_at' => now(),
        ]);
    }

    public function draft(): static
    {
        return $this->state(fn (): array => [
            'is_published' => false,
            'published_at' => null,
        ]);
    }

    public function category(PostCategory $category): static
    {
        return $this->state(fn (): array => ['category' => $category->value]);
    }
}