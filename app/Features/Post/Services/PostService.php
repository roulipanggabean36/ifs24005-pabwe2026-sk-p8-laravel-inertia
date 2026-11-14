<?php

declare(strict_types=1);

namespace App\Features\Post\Services;

use App\Features\Post\Contracts\PostRepositoryInterface;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\UploadedFile;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class PostService
{
    public function __construct(private readonly PostRepositoryInterface $posts) {}

    /**
     * @return LengthAwarePaginator<int, Post>
     */
    public function listPublic(?string $search, ?string $category): LengthAwarePaginator
    {
        return $this->posts->paginatePublic($search, $category);
    }

    public function findPublished(string $slug): ?Post
    {
        return $this->posts->findPublishedBySlug($slug);
    }

    /**
     * @return LengthAwarePaginator<int, Post>
     */
    public function listForUser(int $userId, ?string $search, ?string $category, ?string $status): LengthAwarePaginator
    {
        return $this->posts->paginateForUser($userId, $search, $category, $status);
    }

    /**
     * @return LengthAwarePaginator<int, Post>
     */
    public function listAll(?string $search, ?string $category, ?string $status): LengthAwarePaginator
    {
        return $this->posts->paginateAll($search, $category, $status);
    }

    /**
     * @return array{total: int, published: int, draft: int}
     */
    public function statsForUser(int $userId): array
    {
        return $this->posts->statsForUser($userId);
    }

    /**
     * @return Collection<int, Post>
     */
    public function exportForUser(int $userId): Collection
    {
        return $this->posts->forExport($userId);
    }

    /**
     * @return Collection<int, Post>
     */
    public function exportAll(): Collection
    {
        return $this->posts->forExport();
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User $user, array $data, ?UploadedFile $cover = null): Post
    {
        $published = (bool) ($data['is_published'] ?? false);

        $payload = [
            'user_id' => $user->id,
            'title' => $data['title'],
            'slug' => $this->uniqueSlug($data['title']),
            'category' => $data['category'],
            'excerpt' => $this->resolveExcerpt($data['excerpt'] ?? null, $data['content']),
            'content' => $data['content'],
            'is_published' => $published,
            'published_at' => $published ? ($data['published_at'] ?? now()) : null,
        ];

        if ($cover !== null) {
            $payload['cover_image_path'] = $this->storeCover($cover);
        }

        return $this->posts->create($payload);
    }

    /**
     * Slug hanya berubah jika judul berubah.
     *
     * @param  array<string, mixed>  $data
     */
    public function update(Post $post, array $data): Post
    {
        $payload = [
            'title' => $data['title'],
            'category' => $data['category'],
            'excerpt' => $this->resolveExcerpt($data['excerpt'] ?? null, $data['content']),
            'content' => $data['content'],
        ];

        if ($data['title'] !== $post->title) {
            $payload['slug'] = $this->uniqueSlug($data['title'], $post->id);
        }

        if (isset($data['is_published'])) {
            $payload += $this->publishState($post, (bool) $data['is_published']);
        }

        return $this->posts->update($post, $payload);
    }

    public function delete(Post $post): void
    {
        $this->deleteCoverFile($post->cover_image_path);
        $this->posts->delete($post);
    }

    public function togglePublish(Post $post): Post
    {
        return $this->posts->update($post, $this->publishState($post, ! $post->is_published));
    }

    public function uploadCover(Post $post, UploadedFile $cover): Post
    {
        $this->deleteCoverFile($post->cover_image_path);

        return $this->posts->update($post, ['cover_image_path' => $this->storeCover($cover)]);
    }

    public function removeCover(Post $post): Post
    {
        $this->deleteCoverFile($post->cover_image_path);

        return $this->posts->update($post, ['cover_image_path' => null]);
    }

    /**
     * Simpan batch artikel (hasil AI) sebagai draf dalam satu transaksi.
     *
     * @param  list<array<string, mixed>>  $items
     */
    public function createMany(User $user, array $items): int
    {
        return DB::transaction(function () use ($user, $items): int {
            foreach ($items as $item) {
                $this->create($user, [
                    'title' => $item['title'],
                    'category' => $item['category'],
                    'excerpt' => $item['excerpt'] ?? null,
                    'content' => $item['content'],
                    'is_published' => false,
                ]);
            }

            return count($items);
        });
    }

    /**
     * @return array{is_published: bool, published_at: mixed}
     */
    private function publishState(Post $post, bool $published): array
    {
        if (! $published) {
            return ['is_published' => false, 'published_at' => null];
        }

        return ['is_published' => true, 'published_at' => $post->published_at ?? now()];
    }

    private function uniqueSlug(string $title, ?int $ignoreId = null): string
    {
        $base = Str::limit(Str::slug($title), 200, '');

        if ($base === '') {
            $base = 'artikel';
        }

        $slug = $base;
        $suffix = 2;

        while ($this->posts->slugExists($slug, $ignoreId)) {
            $slug = $base.'-'.$suffix;
            $suffix++;
        }

        return $slug;
    }

    private function resolveExcerpt(?string $excerpt, string $content): string
    {
        $excerpt = trim((string) $excerpt);

        if ($excerpt !== '') {
            return $excerpt;
        }

        return (string) Str::of($content)
            ->stripTags()
            ->replaceMatches('/[#*>`_~\[\]()!\-]+/', ' ')
            ->squish()
            ->limit(160);
    }

    private function storeCover(UploadedFile $cover): string
    {
        return (string) $cover->store('covers', 'public');
    }

    private function deleteCoverFile(?string $path): void
    {
        if ($path !== null) {
            Storage::disk('public')->delete($path);
        }
    }
}