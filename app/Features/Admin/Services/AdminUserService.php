<?php

declare(strict_types=1);

namespace App\Features\Admin\Services;

use App\Features\Post\Models\Post;
use App\Features\Post\Services\PostService;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

class AdminUserService
{
    public function __construct(private readonly PostService $posts) {}

    /**
     * @return LengthAwarePaginator<int, User>
     */
    public function listUsers(?string $search, int $perPage = 10): LengthAwarePaginator
    {
        $term = trim((string) $search);

        return User::query()
            ->withCount('posts')
            ->when($term !== '', function (Builder $query) use ($term): void {
                $pattern = '%'.addcslashes(mb_strtolower($term), '\\%_').'%';

                $query->where(function (Builder $builder) use ($pattern): void {
                    $builder->whereRaw("LOWER(name) LIKE ? ESCAPE '\\'", [$pattern])
                        ->orWhereRaw("LOWER(username) LIKE ? ESCAPE '\\'", [$pattern]);
                });
            })
            ->orderBy('name')
            ->orderBy('id')
            ->paginate($perPage)
            ->withQueryString();
    }

    /**
     * @return LengthAwarePaginator<int, Post>
     */
    public function postsForUser(User $user, ?string $search, ?string $category, ?string $status): LengthAwarePaginator
    {
        return $this->posts->listForUser($user->id, $search, $category, $status);
    }

    /**
     * @return array{total: int, published: int, draft: int}
     */
    public function statsForUser(User $user): array
    {
        return $this->posts->statsForUser($user->id);
    }

    /**
     * @return Collection<int, Post>
     */
    public function exportForUser(User $user): Collection
    {
        return $this->posts->exportForUser($user->id);
    }
}