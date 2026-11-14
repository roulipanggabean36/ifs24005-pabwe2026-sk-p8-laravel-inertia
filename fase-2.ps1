# fase-2.ps1 - jalankan dari root proyek
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

# ---------------------------------------------------------------
# 1. Migrasi
# ---------------------------------------------------------------
W 'database/migrations/0001_01_01_000000_create_users_table.php' @'
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table): void {
            $table->id();
            $table->string('name');
            $table->string('username')->unique();
            $table->string('password');
            $table->string('role')->default('member')->index();
            $table->string('profile_photo_path')->nullable();
            $table->rememberToken();
            $table->timestamps();
        });

        Schema::create('sessions', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('users');
    }
};
'@

W 'database/migrations/2026_11_01_000003_create_posts_table.php' @'
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('posts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title');
            $table->string('slug')->unique();
            $table->string('category');
            $table->text('excerpt')->nullable();
            $table->longText('content');
            $table->string('cover_image_path')->nullable();
            $table->boolean('is_published')->default(false);
            $table->timestamp('published_at')->nullable();
            $table->timestamps();

            $table->index('user_id');
            $table->index('category');
            $table->index('is_published');
            $table->index('published_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('posts');
    }
};
'@

# ---------------------------------------------------------------
# 2. Enum
# ---------------------------------------------------------------
W 'app/Features/Post/Enums/PostCategory.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Post\Enums;

enum PostCategory: string
{
    case Teknologi = 'Teknologi';
    case Pendidikan = 'Pendidikan';
    case GayaHidup = 'Gaya Hidup';
    case Bisnis = 'Bisnis';
    case Opini = 'Opini';
    case Umum = 'Umum';

    public function label(): string
    {
        return match ($this) {
            self::Teknologi => 'Teknologi & Koding',
            self::Pendidikan => 'Pendidikan & Tutorial',
            self::GayaHidup => 'Gaya Hidup & Produktivitas',
            self::Bisnis => 'Bisnis & Karir',
            self::Opini => 'Opini & Pemikiran',
            self::Umum => 'Umum',
        };
    }

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    /**
     * @return list<array{value: string, label: string}>
     */
    public static function options(): array
    {
        return array_map(
            static fn (self $category): array => [
                'value' => $category->value,
                'label' => $category->label(),
            ],
            self::cases(),
        );
    }
}
'@

# ---------------------------------------------------------------
# 3. Model
# ---------------------------------------------------------------
W 'app/Features/Post/Models/Post.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Post\Models;

use App\Models\User;
use Database\Factories\PostFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Post extends Model
{
    /** @use HasFactory<PostFactory> */
    use HasFactory;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'title',
        'slug',
        'category',
        'excerpt',
        'content',
        'cover_image_path',
        'is_published',
        'published_at',
    ];

    /**
     * @var list<string>
     */
    protected $appends = ['cover_url'];

    protected static function newFactory(): PostFactory
    {
        return PostFactory::new();
    }

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'is_published' => 'boolean',
            'published_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @param  Builder<Post>  $query
     * @return Builder<Post>
     */
    public function scopePublished(Builder $query): Builder
    {
        return $query->where('is_published', true);
    }

    protected function coverUrl(): Attribute
    {
        return Attribute::get(
            fn (): ?string => $this->cover_image_path !== null
                ? '/storage/'.ltrim($this->cover_image_path, '/')
                : null
        );
    }
}
'@

W 'app/Models/User.php' @'
<?php

declare(strict_types=1);

namespace App\Models;

use App\Features\Post\Models\Post;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory;

    public const ROLE_ADMIN = 'admin';

    public const ROLE_MEMBER = 'member';

    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'username',
        'password',
        'role',
        'profile_photo_path',
    ];

    /**
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'password' => 'hashed',
        ];
    }

    /**
     * @return HasMany<Post, $this>
     */
    public function posts(): HasMany
    {
        return $this->hasMany(Post::class);
    }

    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    public function profilePhotoUrl(): ?string
    {
        return $this->profile_photo_path !== null
            ? '/storage/'.ltrim($this->profile_photo_path, '/')
            : null;
    }
}
'@

# ---------------------------------------------------------------
# 4. Repository + Interface
# ---------------------------------------------------------------
W 'app/Features/Post/Contracts/PostRepositoryInterface.php' @'
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
'@

W 'app/Features/Post/Repositories/PostRepository.php' @'
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
'@

# ---------------------------------------------------------------
# 5. Factory
# ---------------------------------------------------------------
W 'database/factories/UserFactory.php' @'
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected $model = User::class;

    protected static ?string $password = null;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'username' => fake()->unique()->userName(),
            'password' => static::$password ??= Hash::make('password'),
            'role' => User::ROLE_MEMBER,
            'profile_photo_path' => null,
            'remember_token' => Str::random(10),
        ];
    }

    public function admin(): static
    {
        return $this->state(fn (): array => ['role' => User::ROLE_ADMIN]);
    }

    public function member(): static
    {
        return $this->state(fn (): array => ['role' => User::ROLE_MEMBER]);
    }
}
'@

W 'database/factories/PostFactory.php' @'
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Post>
 */
class PostFactory extends Factory
{
    protected $model = Post::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $title = rtrim(fake()->sentence(6), '.');

        return [
            'user_id' => User::factory(),
            'title' => $title,
            'slug' => Str::slug($title).'-'.fake()->unique()->numberBetween(1000, 9999999),
            'category' => fake()->randomElement(PostCategory::values()),
            'excerpt' => fake()->sentence(12),
            'content' => '## '.fake()->sentence(4)."\n\n".fake()->paragraph(4)."\n\n".fake()->paragraph(3),
            'cover_image_path' => null,
            'is_published' => true,
            'published_at' => now(),
        ];
    }

    public function published(): static
    {
        return $this->state(fn (): array => [
            'is_published' => true,
            'published_at' => now(),
        ]);
    }

    public function draft(): static
    {
        return $this->state(fn (): array => [
            'is_published' => false,
            'published_at' => null,
        ]);
    }

    public function category(PostCategory $category): static
    {
        return $this->state(fn (): array => ['category' => $category->value]);
    }
}
'@

# ---------------------------------------------------------------
# 6. Seeder
# ---------------------------------------------------------------
W 'database/seeders/DatabaseSeeder.php' @'
<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::query()->create([
            'name' => 'Administrator',
            'username' => 'admin',
            'password' => 'admin',
            'role' => User::ROLE_ADMIN,
        ]);

        $member = User::query()->create([
            'name' => 'Penulis Demo',
            'username' => 'member',
            'password' => 'member',
            'role' => User::ROLE_MEMBER,
        ]);

        $this->seedPosts($member, [
            [
                'Memulai Belajar Laravel dari Nol',
                PostCategory::Teknologi,
                'Panduan singkat memahami routing, controller, dan Eloquent untuk pemula.',
                "## Mengapa Laravel?\n\nLaravel menawarkan struktur yang rapi dan ekosistem yang lengkap.\n\n- Routing yang ekspresif\n- Eloquent ORM\n- Migrasi database\n\n> Mulailah dari proyek kecil, lalu tingkatkan perlahan.",
                true,
                1,
            ],
            [
                'Tips Belajar Efektif untuk Mahasiswa',
                PostCategory::Pendidikan,
                'Strategi belajar terstruktur agar waktu tidak terbuang percuma.',
                "## Atur Jadwal\n\n1. Tentukan target mingguan\n2. Gunakan teknik pomodoro\n3. Evaluasi setiap akhir pekan\n\nKonsistensi lebih penting daripada durasi.",
                true,
                3,
            ],
            [
                'Membangun Rutinitas Pagi yang Produktif',
                PostCategory::GayaHidup,
                'Langkah sederhana memulai hari dengan fokus dan energi.',
                "## Mulai Kecil\n\nBangun lebih awal selama 15 menit, minum air putih, lalu tulis tiga prioritas hari ini.\n\n**Kunci:** lakukan setiap hari.",
                true,
                5,
            ],
            [
                'Dasar-Dasar Memulai Bisnis Digital',
                PostCategory::Bisnis,
                'Mengenal validasi ide, target pasar, dan model pendapatan.',
                "## Validasi Dulu\n\nSebelum membangun produk, pastikan ada masalah nyata yang ingin diselesaikan.\n\n- Wawancarai calon pengguna\n- Buat prototipe sederhana\n- Ukur minat pasar",
                true,
                7,
            ],
            [
                'Catatan Pribadi tentang Kerja Jarak Jauh',
                PostCategory::Opini,
                'Refleksi pengalaman bekerja dari rumah (masih draf).',
                "## Draf\n\nBekerja jarak jauh memberi fleksibilitas, namun butuh disiplin tinggi.",
                false,
                0,
            ],
            [
                'Rencana Konten Bulan Depan',
                PostCategory::Umum,
                'Daftar ide artikel yang akan ditulis (masih draf).',
                "## Ide Artikel\n\n- Review buku\n- Tutorial Inertia\n- Tips produktivitas",
                false,
                0,
            ],
        ]);

        $this->seedPosts($admin, [
            [
                'Selamat Datang di BlogVerse Pro',
                PostCategory::Umum,
                'Platform publikasi artikel multi-tier untuk semua penulis.',
                "## Halo, Penulis!\n\nBlogVerse Pro adalah tempat berbagi tulisan. Daftar, tulis, lalu terbitkan.",
                true,
                10,
            ],
            [
                'Panduan Menulis Artikel yang Menarik',
                PostCategory::Pendidikan,
                'Struktur judul, pembuka, isi, dan penutup yang memikat pembaca.',
                "## Struktur Dasar\n\n1. Judul yang jelas\n2. Pembuka yang kuat\n3. Isi yang runtut\n4. Penutup yang berkesan",
                true,
                12,
            ],
            [
                'Draf Pengumuman Pemeliharaan Sistem',
                PostCategory::Teknologi,
                'Jadwal pemeliharaan sistem (belum dipublikasikan).',
                "## Jadwal\n\nAkan diumumkan setelah dikonfirmasi tim infrastruktur.",
                false,
                0,
            ],
        ]);

        $this->command?->info('Seeded: '.User::query()->count().' users, '.Post::query()->count().' posts.');
    }

    /**
     * @param  list<array{0: string, 1: PostCategory, 2: string, 3: string, 4: bool, 5: int}>  $items
     */
    private function seedPosts(User $user, array $items): void
    {
        foreach ($items as [$title, $category, $excerpt, $content, $published, $daysAgo]) {
            Post::query()->create([
                'user_id' => $user->id,
                'title' => $title,
                'slug' => Str::slug($title),
                'category' => $category->value,
                'excerpt' => $excerpt,
                'content' => $content,
                'is_published' => $published,
                'published_at' => $published ? now()->subDays($daysAgo) : null,
            ]);
        }
    }
}
'@

# ---------------------------------------------------------------
# 7. Lint sintaks PHP semua file Fase 2
# ---------------------------------------------------------------
$phpFiles = @(
  'database/migrations/0001_01_01_000000_create_users_table.php',
  'database/migrations/2026_11_01_000003_create_posts_table.php',
  'app/Features/Post/Enums/PostCategory.php',
  'app/Features/Post/Models/Post.php',
  'app/Models/User.php',
  'app/Features/Post/Contracts/PostRepositoryInterface.php',
  'app/Features/Post/Repositories/PostRepository.php',
  'database/factories/UserFactory.php',
  'database/factories/PostFactory.php',
  'database/seeders/DatabaseSeeder.php'
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

Write-Host ""
Write-Host "FASE 2 (file) SELESAI. Lanjut ke verifikasi migrate:fresh --seed." -ForegroundColor Green