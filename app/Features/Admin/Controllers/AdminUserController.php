<?php

declare(strict_types=1);

namespace App\Features\Admin\Controllers;

use App\Features\Admin\Services\AdminUserService;
use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Features\Post\Services\PostExcelService;
use App\Models\User;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminUserController
{
    public function __construct(
        private readonly AdminUserService $service,
        private readonly PostExcelService $excel,
    ) {}

    public function index(Request $request): Response
    {
        $data = $request->validate(['search' => ['nullable', 'string', 'max:100']]);
        $search = $data['search'] ?? '';

        $users = $this->service
            ->listUsers($search)
            ->through(fn (User $user): array => $user->only([
                'id', 'name', 'username', 'role', 'posts_count', 'created_at',
            ]) + ['photo_url' => $user->profilePhotoUrl()]);

        return Inertia::render('Admin/UserList', [
            'users' => $users,
            'filters' => ['search' => $search],
        ]);
    }

    public function posts(Request $request, User $user): Response
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
            ->postsForUser($user, $filters['search'], $filters['category'], $filters['status'])
            ->through(fn (Post $post): array => $post->only([
                'id', 'title', 'slug', 'category', 'excerpt',
                'is_published', 'published_at', 'cover_url', 'created_at',
            ]));

        return Inertia::render('Admin/UserPostList', [
            'owner' => $user->only(['id', 'name', 'username']),
            'posts' => $posts,
            'stats' => $this->service->statsForUser($user),
            'filters' => $filters,
            'categories' => PostCategory::options(),
        ]);
    }

    public function exportPosts(User $user): StreamedResponse
    {
        return $this->excel->download(
            $this->service->exportForUser($user),
            true,
            'artikel-'.$user->username.'-'.now()->format('Ymd-His').'.xlsx',
        );
    }
}