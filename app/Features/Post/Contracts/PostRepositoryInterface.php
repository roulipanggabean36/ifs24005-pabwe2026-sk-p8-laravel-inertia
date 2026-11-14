<?php

declare(strict_types=1);

namespace App\Features\Post\Contracts;

use App\Features\Post\Models\Post;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

interface PostRepositoryInterface
{
    /**
     * Artikel terbit untuk publik (search + filter kategori).
     *
     * @return LengthAwarePaginator<int, Post>
     */
    public function paginatePublic(?string $search, ?string $category, int $perPage = 9): LengthAwarePaginator;

    public function findPublishedBySlug(string $slug): ?Post;

    /**
     * Artikel milik satu pengguna.
     *
     * @return LengthAwarePaginator<int, Post>
     */
    public function paginateForUser(
        int $userId,
        ?string $search,
        ?string $category,
        ?string $status,
        int $perPage = 10,
    ): LengthAwarePaginator;

    /**
     * Seluruh artikel sistem (monitoring admin).
     *
     * @return LengthAwarePaginator<int, Post>
     */
    public function paginateAll(
        ?string $search,
        ?string $category,
        ?string $status,
        int $perPage = 10,
    ): LengthAwarePaginator;

    /**
     * @return array{total: int, published: int, draft: int}
     */
    public function statsForUser(int $userId): array;

    /**
     * Data untuk ekspor Excel. $userId null = seluruh sistem.
     *
     * @return Collection<int, Post>
     */
    public function forExport(?int $userId = null): Collection;

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(array $data): Post;

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Post $post, array $data): Post;

    public function delete(Post $post): void;

    public function slugExists(string $slug, ?int $ignoreId = null): bool;
}