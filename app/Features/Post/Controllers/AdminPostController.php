<?php

declare(strict_types=1);

namespace App\Features\Post\Controllers;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Features\Post\Services\PostExcelService;
use App\Features\Post\Services\PostService;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminPostController
{
    public function __construct(
        private readonly PostService $service,
        private readonly PostExcelService $excel,
    ) {}

    public function index(Request $request): Response
    {
        $data = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'category' => ['nullable', 'string', 'max:50'],
            'status' => ['nullable', 'in:published,draft'],
        ]);

        $filters = [
            'search' => $data['search'] ?? '',
            'category' => $data['category'] ?? '',
            'status' => $data['status'] ?? '',
        ];

        $posts = $this->service
            ->listAll($filters['search'], $filters['category'], $filters['status'])
            ->through(fn (Post $post): array => $post->only([
                'id', 'title', 'slug', 'category', 'excerpt',
                'is_published', 'published_at', 'cover_url', 'created_at',
            ]) + [
                'author' => $post->user->name,
                'author_username' => $post->user->username,
            ]);

        return Inertia::render('Admin/PostList', [
            'posts' => $posts,
            'filters' => $filters,
            'categories' => PostCategory::options(),
        ]);
    }

    public function export(): StreamedResponse
    {
        return $this->excel->download(
            $this->service->exportAll(),
            true,
            'semua-artikel-'.now()->format('Ymd-His').'.xlsx',
        );
    }
}