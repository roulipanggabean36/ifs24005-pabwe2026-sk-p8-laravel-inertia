<?php

declare(strict_types=1);

namespace App\Features\Post\Repositories;

use App\Features\Post\Contracts\PostRepositoryInterface;
use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

class PostRepository implements PostRepositoryInterface
{
    public function paginatePublic(?string $search, ?string $category, int $perPage = 9): LengthAwarePaginator
    {
        $query = Post::query()
            ->published()
            ->with('user:id,name,username');

        return $this->applyFilters($query, $search, $category)
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->paginate($perPage)
            ->withQueryString();
    }

    public function findPublishedBySlug(string $slug): ?Post
    {
        return Post::query()
            ->published()
            ->with('user:id,name,username')
            ->where('slug', $slug)
            ->first();
    }

    public function paginateForUser(
        int $userId,
        ?string $search,
        ?string $category,
        ?string $status,
        int $perPage = 10,
    ): LengthAwarePaginator {
        $query = Post::query()->where('user_id', $userId);

        return $this->applyFilters($query, $search, $category, $status)
            ->latest('id')
            ->paginate($perPage)
            ->withQueryString();
    }

    public function paginateAll(
        ?string $search,
        ?string $category,
        ?string $status,
        int $perPage = 10,
    ): LengthAwarePaginator {
        $query = Post::query()->with('user:id,name,username');

        return $this->applyFilters($query, $search, $category, $status)
            ->latest('id')
            ->paginate($perPage)
            ->withQueryString();
    }

    public function statsForUser(int $userId): array
    {
        $total = Post::query()->where('user_id', $userId)->count();
        $published = Post::query()->where('user_id', $userId)->where('is_published', true)->count();

        return [
            'total' => $total,
            'published' => $published,
            'draft' => $total - $published,
        ];
    }

    public function forExport(?int $userId = null): Collection
    {
        $query = Post::query()->with('user:id,name,username')->orderBy('id');

        if ($userId !== null) {
            $query->where('user_id', $userId);
        }

        return $query->get();
    }

    public function create(array $data): Post
    {
        return Post::query()->create($data);
    }

    public function update(Post $post, array $data): Post
    {
        $post->fill($data)->save();

        return $post;
    }

    public function delete(Post $post): void
    {
        $post->delete();
    }

    public function slugExists(string $slug, ?int $ignoreId = null): bool
    {
        return Post::query()
            ->where('slug', $slug)
            ->when($ignoreId !== null, fn (Builder $query) => $query->where('id', '!=', $ignoreId))
            ->exists();
    }

    /**
     * @param  Builder<Post>  $query
     * @return Builder<Post>
     */
    private function applyFilters(
        Builder $query,
        ?string $search,
        ?string $category,
        ?string $status = null,
    ): Builder {
        $term = trim((string) $search);

        if ($term !== '') {
            // Escape karakter khusus LIKE agar % dan _ diperlakukan literal.
            $pattern = '%'.addcslashes($term, '\\%_').'%';

            $query->where(function (Builder $builder) use ($pattern): void {
                $builder->where('title', 'ILIKE', $pattern)
                    ->orWhere('content', 'ILIKE', $pattern);
            });
        }

        if ($category !== null && PostCategory::tryFrom($category) !== null) {
            $query->where('category', $category);
        }

        if ($status === 'published') {
            $query->where('is_published', true);
        } elseif ($status === 'draft') {
            $query->where('is_published', false);
        }

        return $query;
    }
}