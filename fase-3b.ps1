# fase-3b.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path .\artisan)) {
  Write-Host "GAGAL: jalankan dari root proyek Laravel." -ForegroundColor Red
  exit 1
}
if (-not (Test-Path 'app/Features/Auth/Controllers/AuthController.php')) {
  Write-Host "GAGAL: file Fase 3a belum ada. Jalankan fase-3a.ps1 dulu." -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------
# 1. Policy
# ---------------------------------------------------------------
W 'app/Features/Post/Policies/PostPolicy.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Post\Policies;

use App\Features\Post\Models\Post;
use App\Models\User;

class PostPolicy
{
    public function view(User $user, Post $post): bool
    {
        return $this->owns($user, $post);
    }

    public function update(User $user, Post $post): bool
    {
        return $this->owns($user, $post);
    }

    public function delete(User $user, Post $post): bool
    {
        return $this->owns($user, $post);
    }

    private function owns(User $user, Post $post): bool
    {
        return $user->id === $post->user_id;
    }
}
'@

# ---------------------------------------------------------------
# 2. PostService
# ---------------------------------------------------------------
W 'app/Features/Post/Services/PostService.php' @'
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
'@

# ---------------------------------------------------------------
# 3. PostExcelService
# ---------------------------------------------------------------
W 'app/Features/Post/Services/PostExcelService.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Post\Services;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Throwable;

class PostExcelService
{
    public const MAX_IMPORT_ROWS = 500;

    private const STATUS_PUBLISHED = ['terbit', 'published'];

    private const STATUS_DRAFT = ['draf', 'draft'];

    public function __construct(private readonly PostService $service) {}

    /**
     * @param  Collection<int, Post>  $posts
     */
    public function download(Collection $posts, bool $withAuthor, string $filename): StreamedResponse
    {
        $spreadsheet = $this->buildSpreadsheet($posts, $withAuthor);

        return response()->streamDownload(
            function () use ($spreadsheet): void {
                (new Xlsx($spreadsheet))->save('php://output');
            },
            $filename,
            ['Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
        );
    }

    /**
     * @param  Collection<int, Post>  $posts
     */
    public function buildSpreadsheet(Collection $posts, bool $withAuthor): Spreadsheet
    {
        $headers = ['Judul', 'Slug', 'Kategori', 'Ringkasan', 'Isi', 'Status', 'Tanggal Publikasi'];

        if ($withAuthor) {
            $headers[] = 'Penulis';
        }

        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Artikel');

        foreach ($headers as $index => $header) {
            $column = Coordinate::stringFromColumnIndex($index + 1);
            $sheet->setCellValueExplicit($column.'1', $header, DataType::TYPE_STRING);
        }

        $lastColumn = Coordinate::stringFromColumnIndex(count($headers));
        $sheet->getStyle('A1:'.$lastColumn.'1')->getFont()->setBold(true);

        $rowNumber = 2;

        foreach ($posts as $post) {
            $values = [
                $post->title,
                $post->slug,
                $post->category,
                (string) $post->excerpt,
                $post->content,
                $post->is_published ? 'Terbit' : 'Draf',
                $post->published_at?->format('Y-m-d H:i:s') ?? '',
            ];

            if ($withAuthor) {
                $values[] = $post->user->name;
            }

            foreach ($values as $index => $value) {
                // Selalu string agar isi yang diawali "=" tidak dievaluasi sebagai formula.
                $column = Coordinate::stringFromColumnIndex($index + 1);
                $sheet->setCellValueExplicit($column.$rowNumber, (string) $value, DataType::TYPE_STRING);
            }

            $rowNumber++;
        }

        foreach (range(1, count($headers)) as $index) {
            $sheet->getColumnDimension(Coordinate::stringFromColumnIndex($index))->setAutoSize(true);
        }

        $sheet->getColumnDimension('E')->setAutoSize(false)->setWidth(60);

        return $spreadsheet;
    }

    /**
     * @return array{imported: int, errors: list<array{row: int, message: string}>}
     */
    public function import(User $user, UploadedFile $file): array
    {
        try {
            $rows = IOFactory::load($file->getRealPath())
                ->getActiveSheet()
                ->toArray(null, true, true, false);
        } catch (Throwable) {
            return $this->failure('File Excel tidak dapat dibaca. Gunakan format .xlsx atau .xls.');
        }

        $map = [];

        foreach (($rows[0] ?? []) as $index => $heading) {
            $map[mb_strtolower(trim((string) $heading))] = $index;
        }

        $missing = array_values(array_filter(
            ['Judul', 'Kategori', 'Isi'],
            static fn (string $required): bool => ! isset($map[mb_strtolower($required)]),
        ));

        if ($missing !== []) {
            return $this->failure('Kolom wajib tidak ditemukan: '.implode(', ', $missing).'.');
        }

        if (count($rows) - 1 > self::MAX_IMPORT_ROWS) {
            return $this->failure('Maksimal '.self::MAX_IMPORT_ROWS.' baris data per berkas.');
        }

        $valid = [];
        $errors = [];

        foreach (array_slice($rows, 1, null, true) as $index => $row) {
            $cell = static fn (string $key): string => trim((string) ($row[$map[$key] ?? -1] ?? ''));

            $data = [
                'title' => $cell('judul'),
                'category' => $this->normalizeCategory($cell('kategori')),
                'excerpt' => $cell('ringkasan'),
                'content' => $cell('isi'),
                'status' => mb_strtolower($cell('status')),
            ];

            if (implode('', $data) === '') {
                continue;
            }

            $validator = Validator::make($data, [
                'title' => ['required', 'string', 'max:255'],
                'category' => ['required', Rule::in(PostCategory::values())],
                'excerpt' => ['nullable', 'string', 'max:1000'],
                'content' => ['required', 'string'],
                'status' => ['nullable', Rule::in([...self::STATUS_PUBLISHED, ...self::STATUS_DRAFT])],
            ], [], [
                'title' => 'Judul',
                'category' => 'Kategori',
                'excerpt' => 'Ringkasan',
                'content' => 'Isi',
                'status' => 'Status',
            ]);

            if ($validator->fails()) {
                $errors[] = ['row' => $index + 1, 'message' => implode(' ', $validator->errors()->all())];

                continue;
            }

            $published = in_array($data['status'], self::STATUS_PUBLISHED, true);

            $valid[] = [
                'title' => $data['title'],
                'category' => $data['category'],
                'excerpt' => $data['excerpt'],
                'content' => $data['content'],
                'is_published' => $published,
                'published_at' => $published ? $this->parseDate($cell('tanggal publikasi')) : null,
            ];
        }

        DB::transaction(function () use ($user, $valid): void {
            foreach ($valid as $item) {
                $this->service->create($user, $item);
            }
        });

        return ['imported' => count($valid), 'errors' => $errors];
    }

    /**
     * @return array{imported: int, errors: list<array{row: int, message: string}>}
     */
    private function failure(string $message): array
    {
        return ['imported' => 0, 'errors' => [['row' => 1, 'message' => $message]]];
    }

    private function normalizeCategory(string $input): string
    {
        foreach (PostCategory::cases() as $category) {
            if (mb_strtolower($category->value) === mb_strtolower($input)) {
                return $category->value;
            }
        }

        return $input;
    }

    private function parseDate(string $value): CarbonInterface
    {
        if ($value === '') {
            return now();
        }

        try {
            return Carbon::parse($value);
        } catch (Throwable) {
            return now();
        }
    }
}
'@

# ---------------------------------------------------------------
# 4. Controller: Post (member)
# ---------------------------------------------------------------
W 'app/Features/Post/Controllers/PostController.php' @'
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
'@

# ---------------------------------------------------------------
# 5. Controller: Public
# ---------------------------------------------------------------
W 'app/Features/Post/Controllers/PublicPostController.php' @'
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
'@

# ---------------------------------------------------------------
# 6. Controller: Admin (monitoring semua artikel, read-only)
# ---------------------------------------------------------------
W 'app/Features/Post/Controllers/AdminPostController.php' @'
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
'@

# ---------------------------------------------------------------
# 7. Lint sintaks PHP + cek class bisa dimuat
# ---------------------------------------------------------------
$phpFiles = @(
  'app/Features/Post/Policies/PostPolicy.php',
  'app/Features/Post/Services/PostService.php',
  'app/Features/Post/Services/PostExcelService.php',
  'app/Features/Post/Controllers/PostController.php',
  'app/Features/Post/Controllers/PublicPostController.php',
  'app/Features/Post/Controllers/AdminPostController.php'
)
foreach ($f in $phpFiles) {
  php -l $f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: sintaks PHP salah di $f" -ForegroundColor Red
    php -l $f
    exit 1
  }
}
Write-Host "Lint PHP: semua file valid." -ForegroundColor Green

W 'tmp-check-3b.php' @'
<?php
require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$classes = [
    App\Features\Post\Policies\PostPolicy::class,
    App\Features\Post\Services\PostService::class,
    App\Features\Post\Services\PostExcelService::class,
    App\Features\Post\Controllers\PublicPostController::class,
    App\Features\Post\Controllers\AdminPostController::class,
    App\Features\Post\Controllers\PostController::class,
    App\Features\Auth\Controllers\AuthController::class,
    App\Features\Profile\Controllers\ProfileController::class,
    App\Http\Middleware\EnsureRole::class,
    App\Http\Middleware\EnsurePostOwnership::class,
    App\Http\Middleware\HandleInertiaRequests::class,
];
$bad = 0;
foreach ($classes as $class) {
    $ok = class_exists($class);
    echo ($ok ? 'OK   ' : 'GAGAL ') . $class . PHP_EOL;
    if (! $ok) { $bad++; }
}
exit($bad === 0 ? 0 : 1);
'@
php tmp-check-3b.php
$checkExit = $LASTEXITCODE
Remove-Item tmp-check-3b.php -Force
if ($checkExit -ne 0) {
  Write-Host "GAGAL: ada class yang tidak bisa dimuat (lihat daftar di atas)." -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "FASE 3b SELESAI." -ForegroundColor Green