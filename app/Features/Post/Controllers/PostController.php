<?php

declare(strict_types=1);

namespace App\Features\Post\Controllers;

use App\Features\Ai\DTO\GeneratedPostItem;
use App\Features\Ai\Services\OpenAiPostGeneratorService;
use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Features\Post\Services\PostExcelService;
use App\Features\Post\Services\PostService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;
use RuntimeException;
use Symfony\Component\HttpFoundation\StreamedResponse;

class PostController
{
    public const AI_MAX = 10;

    private const COVER_RULES = ['file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'];

    public function __construct(
        private readonly PostService $service,
        private readonly PostExcelService $excel,
    ) {}

    public function index(Request $request): Response
    {
        $filters = $this->filters($request);
        $userId = $request->user()->id;

        $posts = $this->service
            ->listForUser($userId, $filters['search'], $filters['category'], $filters['status'])
            ->through(fn (Post $post): array => $this->present($post));

        return Inertia::render('Post/Index', [
            'posts' => $posts,
            'stats' => $this->service->statsForUser($userId),
            'filters' => $filters,
            'categories' => PostCategory::options(),
            'aiMax' => self::AI_MAX,
        ]);
    }

    public function show(Post $post): Response
    {
        Gate::authorize('view', $post);

        return Inertia::render('Post/Show', [
            'post' => $this->present($post),
            'categories' => PostCategory::options(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate($this->rules() + [
            'cover' => ['nullable', ...self::COVER_RULES],
        ]);

        $this->service->create($request->user(), $data, $request->file('cover'));

        return redirect()
            ->route('dashboard.posts.index')
            ->with('success', 'Artikel berhasil dibuat.');
    }

    public function update(Request $request, Post $post): RedirectResponse
    {
        Gate::authorize('update', $post);

        $data = $request->validate($this->rules());

        $this->service->update($post, $data);

        return redirect()->back()->with('success', 'Artikel berhasil diperbarui.');
    }

    public function destroy(Post $post): RedirectResponse
    {
        Gate::authorize('delete', $post);

        $this->service->delete($post);

        return redirect()
            ->route('dashboard.posts.index')
            ->with('success', 'Artikel berhasil dihapus.');
    }

    public function publish(Post $post): RedirectResponse
    {
        Gate::authorize('update', $post);

        $post = $this->service->togglePublish($post);

        return redirect()->back()->with(
            'success',
            $post->is_published ? 'Artikel dipublikasikan.' : 'Artikel dijadikan draf.',
        );
    }

    public function uploadCover(Request $request, Post $post): RedirectResponse
    {
        Gate::authorize('update', $post);

        $data = $request->validate(['cover' => ['required', ...self::COVER_RULES]]);

        $this->service->uploadCover($post, $data['cover']);

        return redirect()->back()->with('success', 'Foto sampul berhasil diunggah.');
    }

    public function removeCover(Post $post): RedirectResponse
    {
        Gate::authorize('update', $post);

        $this->service->removeCover($post);

        return redirect()->back()->with('success', 'Foto sampul berhasil dihapus.');
    }

    public function export(Request $request): StreamedResponse
    {
        return $this->excel->download(
            $this->service->exportForUser($request->user()->id),
            false,
            'artikel-saya-'.now()->format('Ymd-His').'.xlsx',
        );
    }

    public function import(Request $request): RedirectResponse
    {
        $request->validate(['file' => ['required', 'file', 'mimes:xlsx,xls', 'max:5120']]);

        $result = $this->excel->import($request->user(), $request->file('file'));

        $redirect = redirect()->route('dashboard.posts.index');

        if ($result['imported'] > 0) {
            $redirect->with('success', $result['imported'].' artikel berhasil diimpor.');
        } else {
            $redirect->with('error', 'Tidak ada artikel yang berhasil diimpor.');
        }

        if ($result['errors'] !== []) {
            $redirect->with('import_errors', $result['errors']);
        }

        return $redirect;
    }

    public function aiGenerate(Request $request, OpenAiPostGeneratorService $generator): JsonResponse
    {
        $data = $request->validate([
            'topic' => ['required', 'string', 'max:200'],
            'count' => ['required', 'integer', 'min:1', 'max:'.self::AI_MAX],
        ]);

        try {
            $items = $generator->generate($data['topic'], (int) $data['count']);
        } catch (RuntimeException $exception) {
            return response()->json(['message' => $exception->getMessage()], 422);
        }

        return response()->json([
            'items' => array_map(
                static fn (GeneratedPostItem $item): array => $item->toArray(),
                $items,
            ),
        ]);
    }

    public function aiSave(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1', 'max:'.self::AI_MAX],
            'items.*.title' => ['required', 'string', 'max:255'],
            'items.*.category' => ['required', Rule::in(PostCategory::values())],
            'items.*.excerpt' => ['nullable', 'string', 'max:1000'],
            'items.*.content' => ['required', 'string', 'max:200000'],
        ]);

        $count = $this->service->createMany($request->user(), $data['items']);

        return redirect()
            ->route('dashboard.posts.index')
            ->with('success', $count.' artikel hasil AI disimpan sebagai draf.');
    }

    /**
     * @return array<string, array<int, mixed>>
     */
    private function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'category' => ['required', Rule::in(PostCategory::values())],
            'excerpt' => ['nullable', 'string', 'max:1000'],
            'content' => ['required', 'string', 'max:200000'],
            'is_published' => ['nullable', 'boolean'],
        ];
    }

    /**
     * @return array{search: string, category: string, status: string}
     */
    private function filters(Request $request): array
    {
        $data = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'category' => ['nullable', 'string', 'max:50'],
            'status' => ['nullable', 'in:published,draft'],
        ]);

        return [
            'search' => $data['search'] ?? '',
            'category' => $data['category'] ?? '',
            'status' => $data['status'] ?? '',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function present(Post $post): array
    {
        return $post->only([
            'id', 'title', 'slug', 'category', 'excerpt', 'content',
            'is_published', 'published_at', 'cover_url', 'created_at', 'updated_at',
        ]);
    }
}