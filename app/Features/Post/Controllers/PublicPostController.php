<?php

declare(strict_types=1);

namespace App\Features\Post\Controllers;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Features\Post\Services\PostService;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class PublicPostController
{
    public function __construct(private readonly PostService $service) {}

    public function home(Request $request): Response
    {
        return $this->render($request, true);
    }

    public function index(Request $request): Response
    {
        return $this->render($request, false);
    }

    public function show(string $slug): Response
    {
        $post = $this->service->findPublished($slug);

        abort_if($post === null, 404);

        return Inertia::render('Public/PostShow', [
            'post' => $post->only([
                'id', 'title', 'slug', 'category', 'excerpt', 'content', 'cover_url', 'published_at',
            ]) + ['author' => $post->user->name],
        ]);
    }

    private function render(Request $request, bool $isHome): Response
    {
        $data = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'category' => ['nullable', 'string', 'max:50'],
        ]);

        $search = $data['search'] ?? '';
        $category = $data['category'] ?? '';

        $posts = $this->service
            ->listPublic($search, $category)
            ->through(fn (Post $post): array => $post->only([
                'id', 'title', 'slug', 'category', 'excerpt', 'cover_url', 'published_at',
            ]) + ['author' => $post->user->name]);

        return Inertia::render('Public/PostIndex', [
            'posts' => $posts,
            'filters' => ['search' => $search, 'category' => $category],
            'categories' => PostCategory::options(),
            'isHome' => $isHome,
        ]);
    }
}