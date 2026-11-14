# fase-3c.ps1 - jalankan dari root proyek
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
if (-not (Test-Path 'app/Features/Post/Controllers/PostController.php')) {
  Write-Host "GAGAL: file Fase 3b belum ada. Jalankan fase-3b.ps1 dulu." -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------
# 1. AI
# ---------------------------------------------------------------
W 'app/Features/Ai/Contracts/AiClientInterface.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Ai\Contracts;

use RuntimeException;

interface AiClientInterface
{
    /**
     * Mengirim prompt ke penyedia AI dan mengembalikan teks balasan mentah.
     *
     * @throws RuntimeException dengan pesan ramah pengguna bila gagal
     */
    public function complete(string $systemPrompt, string $userPrompt): string;
}
'@

W 'app/Features/Ai/DTO/GeneratedPostItem.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Ai\DTO;

final readonly class GeneratedPostItem
{
    public function __construct(
        public string $title,
        public string $category,
        public string $excerpt,
        public string $content,
    ) {}

    /**
     * @return array{title: string, category: string, excerpt: string, content: string}
     */
    public function toArray(): array
    {
        return [
            'title' => $this->title,
            'category' => $this->category,
            'excerpt' => $this->excerpt,
            'content' => $this->content,
        ];
    }
}
'@

W 'app/Features/Ai/Services/OpenAiPostGeneratorService.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Ai\Services;

use App\Features\Ai\Contracts\AiClientInterface;
use App\Features\Ai\DTO\GeneratedPostItem;
use App\Features\Post\Enums\PostCategory;
use Illuminate\Support\Str;
use RuntimeException;

class OpenAiPostGeneratorService
{
    public const MAX_COUNT = 10;

    public function __construct(private readonly AiClientInterface $client) {}

    /**
     * @return list<GeneratedPostItem>
     *
     * @throws RuntimeException
     */
    public function generate(string $topic, int $count): array
    {
        $count = max(1, min(self::MAX_COUNT, $count));

        $raw = $this->client->complete(
            $this->systemPrompt(),
            sprintf('Buat %d artikel blog berbeda tentang topik: %s', $count, trim($topic)),
        );

        return $this->parse($raw, $count);
    }

    private function systemPrompt(): string
    {
        return sprintf(
            'Anda adalah penulis blog profesional berbahasa Indonesia. '
            .'Balas HANYA dengan satu objek JSON valid, tanpa teks lain dan tanpa pembungkus kode, '
            .'dengan bentuk: {"articles":[{"title":"...","category":"...","excerpt":"...","content":"..."}]}. '
            .'Nilai category harus salah satu dari: %s. '
            .'Nilai excerpt berisi 1-2 kalimat pemikat pembaca. '
            .'Nilai content berisi artikel lengkap berformat Markdown (subjudul ##, paragraf, daftar bila perlu).',
            implode(', ', PostCategory::values()),
        );
    }

    /**
     * @return list<GeneratedPostItem>
     */
    private function parse(string $raw, int $count): array
    {
        $decoded = json_decode($this->stripFences($raw), true);

        if (! is_array($decoded)) {
            throw new RuntimeException('Respons AI tidak dapat dibaca. Silakan coba lagi.');
        }

        $list = array_is_list($decoded) ? $decoded : ($decoded['articles'] ?? null);
        $list = is_array($list) ? $list : [];

        $items = [];

        foreach ($list as $entry) {
            $item = is_array($entry) ? $this->toItem($entry) : null;

            if ($item !== null) {
                $items[] = $item;
            }

            if (count($items) === $count) {
                break;
            }
        }

        if ($items === []) {
            throw new RuntimeException('AI tidak menghasilkan artikel yang dapat digunakan. Coba ubah topik Anda.');
        }

        return $items;
    }

    /**
     * @param  array<array-key, mixed>  $entry
     */
    private function toItem(array $entry): ?GeneratedPostItem
    {
        $title = $this->text($entry['title'] ?? null);
        $content = $this->text($entry['content'] ?? null);

        if ($title === '' || $content === '') {
            return null;
        }

        return new GeneratedPostItem(
            title: Str::limit($title, 255, ''),
            category: $this->category($this->text($entry['category'] ?? null)),
            excerpt: Str::limit($this->text($entry['excerpt'] ?? null), 1000, ''),
            content: $content,
        );
    }

    private function category(string $input): string
    {
        foreach (PostCategory::cases() as $category) {
            if (mb_strtolower($category->value) === mb_strtolower($input)) {
                return $category->value;
            }
        }

        return PostCategory::Umum->value;
    }

    private function text(mixed $value): string
    {
        return is_string($value) ? trim($value) : '';
    }

    private function stripFences(string $raw): string
    {
        return trim((string) preg_replace('/^```(?:json)?\s*|\s*```$/i', '', trim($raw)));
    }
}
'@

# ---------------------------------------------------------------
# 2. Admin
# ---------------------------------------------------------------
W 'app/Features/Admin/Services/AdminUserService.php' @'
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
                $pattern = '%'.addcslashes($term, '\\%_').'%';

                $query->where(function (Builder $builder) use ($pattern): void {
                    $builder->where('name', 'ILIKE', $pattern)
                        ->orWhere('username', 'ILIKE', $pattern);
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
'@

W 'app/Features/Admin/Controllers/AdminUserController.php' @'
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
'@

# ---------------------------------------------------------------
# 3. Rute
# ---------------------------------------------------------------
W 'routes/web.php' @'
<?php

declare(strict_types=1);

use App\Features\Admin\Controllers\AdminUserController;
use App\Features\Auth\Controllers\AuthController;
use App\Features\Post\Controllers\AdminPostController;
use App\Features\Post\Controllers\PostController;
use App\Features\Post\Controllers\PublicPostController;
use App\Features\Profile\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Publik (Guest) - tanpa sidebar
|--------------------------------------------------------------------------
*/
Route::get('/', [PublicPostController::class, 'home'])->name('home');
Route::get('/articles', [PublicPostController::class, 'index'])->name('articles.index');
Route::get('/articles/{slug}', [PublicPostController::class, 'show'])->name('articles.show');

/*
|--------------------------------------------------------------------------
| Autentikasi (Guest)
|--------------------------------------------------------------------------
*/
Route::middleware('guest')->group(function (): void {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login'])->name('login.store');
    Route::get('/register', [AuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [AuthController::class, 'register'])->name('register.store');
});

/*
|--------------------------------------------------------------------------
| Authenticated
|--------------------------------------------------------------------------
*/
Route::middleware('auth')->group(function (): void {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');

    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::put('/profile', [ProfileController::class, 'update'])->name('profile.update');

    // Member (Penulis). Rute statis WAJIB sebelum rute {post}.
    Route::middleware('role:member')
        ->prefix('dashboard/posts')
        ->name('dashboard.posts.')
        ->group(function (): void {
            Route::get('/', [PostController::class, 'index'])->name('index');
            Route::post('/', [PostController::class, 'store'])->name('store');

            Route::get('/export', [PostController::class, 'export'])->name('export');
            Route::post('/import', [PostController::class, 'import'])->name('import');
            Route::post('/ai-generate', [PostController::class, 'aiGenerate'])->name('ai-generate');
            Route::post('/ai-save', [PostController::class, 'aiSave'])->name('ai-save');

            Route::middleware('post.owner')->group(function (): void {
                Route::get('/{post}', [PostController::class, 'show'])->whereNumber('post')->name('show');
                Route::put('/{post}', [PostController::class, 'update'])->whereNumber('post')->name('update');
                Route::delete('/{post}', [PostController::class, 'destroy'])->whereNumber('post')->name('destroy');
                Route::patch('/{post}/publish', [PostController::class, 'publish'])->whereNumber('post')->name('publish');
                Route::post('/{post}/cover', [PostController::class, 'uploadCover'])->whereNumber('post')->name('cover.upload');
                Route::delete('/{post}/cover', [PostController::class, 'removeCover'])->whereNumber('post')->name('cover.remove');
            });
        });

    // Admin
    Route::middleware('role:admin')
        ->prefix('admin')
        ->name('admin.')
        ->group(function (): void {
            Route::get('/users', [AdminUserController::class, 'index'])->name('users.index');
            Route::get('/users/{user}/posts/export', [AdminUserController::class, 'exportPosts'])
                ->whereNumber('user')->name('users.posts.export');
            Route::get('/users/{user}/posts', [AdminUserController::class, 'posts'])
                ->whereNumber('user')->name('users.posts');

            Route::get('/posts/export', [AdminPostController::class, 'export'])->name('posts.export');
            Route::get('/posts', [AdminPostController::class, 'index'])->name('posts.index');
        });
});
'@

# ---------------------------------------------------------------
# 4. AppServiceProvider
# ---------------------------------------------------------------
W 'app/Providers/AppServiceProvider.php' @'
<?php

declare(strict_types=1);

namespace App\Providers;

use App\Features\Ai\Contracts\AiClientInterface;
use App\Features\Post\Contracts\PostRepositoryInterface;
use App\Features\Post\Models\Post;
use App\Features\Post\Policies\PostPolicy;
use App\Features\Post\Repositories\PostRepository;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Lang;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;
use RuntimeException;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(PostRepositoryInterface::class, PostRepository::class);
        $this->app->bind(AiClientInterface::class, fn (): AiClientInterface => $this->makeOpenAiClient());
    }

    public function boot(): void
    {
        if (config('app.force_https')) {
            URL::forceHttps();
        }

        Gate::policy(Post::class, PostPolicy::class);

        Lang::addLines($this->indonesianValidationLines(), 'id');
    }

    private function makeOpenAiClient(): AiClientInterface
    {
        return new class implements AiClientInterface
        {
            public function complete(string $systemPrompt, string $userPrompt): string
            {
                $apiKey = config('openai.api_key');

                if (! is_string($apiKey) || $apiKey === '') {
                    throw new RuntimeException('Kunci API OpenAI belum dikonfigurasi.');
                }

                try {
                    $response = Http::withToken($apiKey)
                        ->acceptJson()
                        ->timeout((int) config('openai.timeout', 60))
                        ->post(rtrim((string) config('openai.base_url'), '/').'/chat/completions', [
                            'model' => (string) config('openai.model'),
                            'messages' => [
                                ['role' => 'system', 'content' => $systemPrompt],
                                ['role' => 'user', 'content' => $userPrompt],
                            ],
                            'response_format' => ['type' => 'json_object'],
                            'temperature' => 0.7,
                        ]);
                } catch (ConnectionException) {
                    throw new RuntimeException('Tidak dapat terhubung ke layanan AI atau waktu tunggu habis. Coba lagi.');
                }

                if ($response->failed()) {
                    throw new RuntimeException('Layanan AI mengembalikan kesalahan ('.$response->status().'). Coba lagi nanti.');
                }

                $content = $response->json('choices.0.message.content');

                if (! is_string($content) || trim($content) === '') {
                    throw new RuntimeException('Layanan AI mengembalikan respons kosong. Coba lagi.');
                }

                return $content;
            }
        };
    }

    /**
     * @return array<string, string>
     */
    private function indonesianValidationLines(): array
    {
        return [
            'validation.required' => ':attribute wajib diisi.',
            'validation.string' => ':attribute harus berupa teks.',
            'validation.integer' => ':attribute harus berupa bilangan bulat.',
            'validation.boolean' => ':attribute harus bernilai benar atau salah.',
            'validation.array' => ':attribute harus berupa daftar.',
            'validation.confirmed' => 'Konfirmasi :attribute tidak cocok.',
            'validation.unique' => ':attribute sudah digunakan.',
            'validation.in' => ':attribute yang dipilih tidak valid.',
            'validation.image' => ':attribute harus berupa gambar.',
            'validation.file' => ':attribute harus berupa berkas.',
            'validation.uploaded' => ':attribute gagal diunggah.',
            'validation.mimes' => ':attribute harus berformat: :values.',
            'validation.alpha_dash' => ':attribute hanya boleh berisi huruf, angka, strip, dan garis bawah.',
            'validation.max.string' => ':attribute maksimal :max karakter.',
            'validation.max.numeric' => ':attribute maksimal :max.',
            'validation.max.file' => ':attribute maksimal :max KB.',
            'validation.max.array' => ':attribute maksimal :max item.',
            'validation.min.string' => ':attribute minimal :min karakter.',
            'validation.min.numeric' => ':attribute minimal :min.',
            'validation.min.array' => ':attribute minimal :min item.',
            'validation.attributes.name' => 'Nama',
            'validation.attributes.username' => 'Username',
            'validation.attributes.password' => 'Kata sandi',
            'validation.attributes.title' => 'Judul',
            'validation.attributes.category' => 'Kategori',
            'validation.attributes.excerpt' => 'Ringkasan',
            'validation.attributes.content' => 'Isi',
            'validation.attributes.cover' => 'Foto sampul',
            'validation.attributes.photo' => 'Foto profil',
            'validation.attributes.file' => 'Berkas',
            'validation.attributes.topic' => 'Topik',
            'validation.attributes.count' => 'Jumlah',
            'validation.attributes.items' => 'Artikel',
            'validation.attributes.search' => 'Pencarian',
            'validation.attributes.status' => 'Status',
            'validation.attributes.is_published' => 'Status publikasi',
        ];
    }
}
'@

# Hapus view bawaan yang tidak dipakai (struktur 3.4 hanya app.blade.php)
if (Test-Path 'resources/views/welcome.blade.php') {
  Remove-Item 'resources/views/welcome.blade.php' -Force
  Write-Host "DEL resources/views/welcome.blade.php"
}

# ---------------------------------------------------------------
# 5. Lint sintaks PHP
# ---------------------------------------------------------------
$phpFiles = @(
  'app/Features/Ai/Contracts/AiClientInterface.php',
  'app/Features/Ai/DTO/GeneratedPostItem.php',
  'app/Features/Ai/Services/OpenAiPostGeneratorService.php',
  'app/Features/Admin/Services/AdminUserService.php',
  'app/Features/Admin/Controllers/AdminUserController.php',
  'routes/web.php',
  'app/Providers/AppServiceProvider.php'
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

# ---------------------------------------------------------------
# 6. Cek class, binding, Policy, dan pesan validasi
# ---------------------------------------------------------------
W 'tmp-check-3c.php' @'
<?php
require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$checks = [
    'AiClientInterface -> klien' => fn () => $app->make(App\Features\Ai\Contracts\AiClientInterface::class) instanceof App\Features\Ai\Contracts\AiClientInterface,
    'PostRepositoryInterface -> PostRepository' => fn () => $app->make(App\Features\Post\Contracts\PostRepositoryInterface::class) instanceof App\Features\Post\Repositories\PostRepository,
    'OpenAiPostGeneratorService bisa di-resolve' => fn () => $app->make(App\Features\Ai\Services\OpenAiPostGeneratorService::class) instanceof App\Features\Ai\Services\OpenAiPostGeneratorService,
    'PostPolicy terdaftar' => fn () => Illuminate\Support\Facades\Gate::getPolicyFor(App\Features\Post\Models\Post::class) instanceof App\Features\Post\Policies\PostPolicy,
    'AdminUserController bisa di-resolve' => fn () => $app->make(App\Features\Admin\Controllers\AdminUserController::class) instanceof App\Features\Admin\Controllers\AdminUserController,
    'PostController bisa di-resolve' => fn () => $app->make(App\Features\Post\Controllers\PostController::class) instanceof App\Features\Post\Controllers\PostController,
    'Pesan validasi Indonesia' => fn () => str_contains(__('validation.required', ['attribute' => 'Judul']), 'wajib diisi'),
];

$bad = 0;
foreach ($checks as $label => $check) {
    try { $ok = (bool) $check(); } catch (Throwable $e) { $ok = false; echo '     ' . $e->getMessage() . PHP_EOL; }
    echo ($ok ? 'OK    ' : 'GAGAL ') . $label . PHP_EOL;
    if (! $ok) { $bad++; }
}
exit($bad === 0 ? 0 : 1);
'@
php tmp-check-3c.php
$checkExit = $LASTEXITCODE
Remove-Item tmp-check-3c.php -Force
if ($checkExit -ne 0) {
  Write-Host "GAGAL: ada pengecekan yang tidak lolos (lihat daftar di atas)." -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------
# 7. Cocokkan route:list dengan tabel 3.5
# ---------------------------------------------------------------
php artisan route:clear | Out-Null
$raw = php artisan route:list --json --except-vendor
if ($LASTEXITCODE -ne 0) {
  Write-Host "GAGAL: php artisan route:list error." -ForegroundColor Red
  $raw
  exit 1
}
$routes = ($raw -join "`n") | ConvertFrom-Json
$have = @()
foreach ($r in $routes) {
  $uri = '/' + ([string]$r.uri).TrimStart('/')
  foreach ($m in (([string]$r.method) -split '\|')) {
    if ($m -ne 'HEAD') { $have += "$m $uri" }
  }
}

$expected = @(
  'GET /', 'GET /articles', 'GET /articles/{slug}',
  'GET /login', 'GET /register', 'POST /login', 'POST /register', 'POST /logout',
  'GET /dashboard/posts', 'POST /dashboard/posts',
  'GET /dashboard/posts/{post}', 'PUT /dashboard/posts/{post}', 'DELETE /dashboard/posts/{post}',
  'PATCH /dashboard/posts/{post}/publish',
  'POST /dashboard/posts/{post}/cover', 'DELETE /dashboard/posts/{post}/cover',
  'GET /dashboard/posts/export', 'POST /dashboard/posts/import',
  'POST /dashboard/posts/ai-generate', 'POST /dashboard/posts/ai-save',
  'GET /profile',
  'GET /admin/users', 'GET /admin/users/{user}/posts', 'GET /admin/users/{user}/posts/export',
  'GET /admin/posts', 'GET /admin/posts/export'
)
$allowedExtra = @('PUT /profile', 'GET /up', 'GET /storage/{path}')

$missing = @($expected | Where-Object { $have -notcontains $_ })
$extra = @($have | Where-Object { ($expected -notcontains $_) -and ($allowedExtra -notcontains $_) })

Write-Host ""
Write-Host ("Rute tabel 3.5 ditemukan: {0} dari {1}" -f ($expected.Count - $missing.Count), $expected.Count)
if ($missing.Count -gt 0) {
  Write-Host "RUTE HILANG:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
if ($extra.Count -gt 0) {
  Write-Host "Rute di luar tabel 3.5 (periksa):" -ForegroundColor Yellow
  $extra | ForEach-Object { Write-Host "  + $_" -ForegroundColor Yellow }
}

Write-Host ""
Write-Host "FASE 3c SELESAI." -ForegroundColor Green