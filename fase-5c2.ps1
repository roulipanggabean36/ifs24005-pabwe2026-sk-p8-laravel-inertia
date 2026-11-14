# fase-5c2.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path 'tests/Feature/AuthTest.php')) {
  Write-Host "GAGAL: jalankan fase-5c1.ps1 dulu." -ForegroundColor Red
  exit 1
}

W 'tests/Feature/PublicPostTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

final class PublicPostTest extends TestCase
{
    use RefreshDatabase;

    public function test_home_lists_published_posts_only(): void
    {
        Post::factory()->count(2)->create();
        Post::factory()->draft()->create(['title' => 'Draf Rahasia']);

        $this->get('/')
            ->assertOk()
            ->assertDontSee('Draf Rahasia')
            ->assertInertia(fn (Assert $page) => $page
                ->component('Public/PostIndex')
                ->where('isHome', true)
                ->where('posts.total', 2)
                ->has('posts.data', 2)
                ->where('filters', ['search' => '', 'category' => ''])
                ->has('categories', 6)
                ->where('categories.0', ['value' => 'Teknologi', 'label' => 'Teknologi & Koding']));
    }

    public function test_list_items_expose_summary_fields_without_the_content(): void
    {
        $user = User::factory()->create(['name' => 'Penulis Satu']);
        Post::factory()->create([
            'user_id' => $user->id,
            'title' => 'Judul Terbit',
            'slug' => 'judul-terbit',
            'cover_image_path' => 'covers/a.jpg',
        ]);

        $this->get('/articles')->assertInertia(fn (Assert $page) => $page
            ->component('Public/PostIndex')
            ->where('isHome', false)
            ->where('posts.data.0.title', 'Judul Terbit')
            ->where('posts.data.0.slug', 'judul-terbit')
            ->where('posts.data.0.author', 'Penulis Satu')
            ->where('posts.data.0.cover_url', '/storage/covers/a.jpg')
            ->has('posts.data.0.published_at')
            ->has('posts.data.0.excerpt')
            ->missing('posts.data.0.content'));
    }

    public function test_search_filters_by_title(): void
    {
        Post::factory()->create(['title' => 'Belajar Laravel', 'content' => 'a']);
        Post::factory()->create(['title' => 'Belajar React', 'content' => 'b']);

        $this->get('/articles?search=laravel')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.data.0.title', 'Belajar Laravel')
            ->where('filters.search', 'laravel'));
    }

    public function test_search_works_on_the_home_page_too(): void
    {
        Post::factory()->create(['title' => 'Kopi Pagi', 'content' => 'a']);
        Post::factory()->create(['title' => 'Teh Sore', 'content' => 'b']);

        $this->get('/?search=kopi')->assertInertia(fn (Assert $page) => $page
            ->where('isHome', true)
            ->has('posts.data', 1)
            ->where('posts.data.0.title', 'Kopi Pagi'));
    }

    public function test_category_filter(): void
    {
        Post::factory()->category(PostCategory::Bisnis)->create();
        Post::factory()->category(PostCategory::Opini)->create();

        $this->get('/articles?category=Bisnis')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.data.0.category', 'Bisnis')
            ->where('filters.category', 'Bisnis'));
    }

    public function test_pagination_keeps_the_query_string(): void
    {
        Post::factory()->count(10)->category(PostCategory::Umum)->create();

        $this->get('/articles?category=Umum')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 9)
            ->where('posts.total', 10)
            ->where('posts.last_page', 2));

        $this->get('/articles?category=Umum&page=2')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)
            ->where('posts.current_page', 2)
            ->where('posts.prev_page_url', fn ($url) => str_contains((string) $url, 'category=Umum')));
    }

    public function test_filters_are_validated(): void
    {
        $this->get('/articles?search='.str_repeat('a', 101))->assertSessionHasErrors('search');
        $this->get('/articles?category='.str_repeat('a', 51))->assertSessionHasErrors('category');
    }

    public function test_signed_in_users_can_read_the_public_pages(): void
    {
        Post::factory()->create();

        $this->actingAs(User::factory()->create())->get('/')->assertOk();
        $this->actingAs(User::factory()->admin()->create())->get('/articles')->assertOk();
    }

    public function test_a_published_article_can_be_read_by_slug(): void
    {
        $post = Post::factory()->create([
            'title' => 'Judul Publik',
            'slug' => 'judul-publik',
            'content' => '## Isi',
        ]);

        $this->get('/articles/judul-publik')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('Public/PostShow')
                ->where('post.title', 'Judul Publik')
                ->where('post.slug', 'judul-publik')
                ->where('post.content', '## Isi')
                ->where('post.author', $post->user->name)
                ->where('post.cover_url', null)
                ->has('post.published_at'));
    }

    public function test_cover_url_is_exposed_on_the_article(): void
    {
        Post::factory()->create(['slug' => 'bersampul', 'cover_image_path' => 'covers/x.jpg']);

        $this->get('/articles/bersampul')->assertInertia(fn (Assert $page) => $page
            ->where('post.cover_url', '/storage/covers/x.jpg'));
    }

    public function test_drafts_and_unknown_slugs_are_not_found(): void
    {
        Post::factory()->draft()->create(['slug' => 'draf-rahasia']);

        $this->get('/articles/draf-rahasia')->assertNotFound();
        $this->get('/articles/tidak-ada')->assertNotFound();
    }
}
'@

W 'tests/Feature/ProfileTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

final class ProfileTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
    }

    public function test_guests_are_redirected_to_login(): void
    {
        $this->get('/profile')->assertRedirect(route('login'));
        $this->put('/profile', [])->assertRedirect(route('login'));
    }

    public function test_the_page_shows_the_current_profile(): void
    {
        $user = User::factory()->create([
            'name' => 'Ani',
            'username' => 'ani',
            'profile_photo_path' => 'profile-photos/a.jpg',
        ]);

        $this->actingAs($user)->get('/profile')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Profile/Edit')
            ->where('profile', [
                'name' => 'Ani',
                'username' => 'ani',
                'photo_url' => '/storage/profile-photos/a.jpg',
            ]));
    }

    public function test_a_member_updates_name_and_username(): void
    {
        $user = User::factory()->create(['name' => 'Lama', 'username' => 'lama', 'password' => 'rahasia123']);

        $this->actingAs($user)
            ->put('/profile', ['name' => 'Baru', 'username' => 'baru'])
            ->assertRedirect(route('profile.edit'))
            ->assertSessionHas('success', 'Profil berhasil diperbarui.');

        $user->refresh();

        $this->assertSame('Baru', $user->name);
        $this->assertSame('baru', $user->username);
        $this->assertTrue(Hash::check('rahasia123', $user->password));
    }

    public function test_an_admin_can_update_the_own_profile(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin)
            ->put('/profile', ['name' => 'Admin Baru', 'username' => 'adminbaru'])
            ->assertRedirect(route('profile.edit'));

        $this->assertSame('Admin Baru', $admin->refresh()->name);
        $this->assertSame('admin', $admin->role);
    }

    public function test_the_current_username_is_not_a_conflict(): void
    {
        $user = User::factory()->create(['username' => 'sama']);

        $this->actingAs($user)
            ->put('/profile', ['name' => 'Nama', 'username' => 'sama'])
            ->assertSessionHasNoErrors();
    }

    public function test_a_username_owned_by_someone_else_is_rejected(): void
    {
        User::factory()->create(['username' => 'dipakai']);
        $user = User::factory()->create(['username' => 'saya']);

        $this->actingAs($user)
            ->from('/profile')
            ->put('/profile', ['name' => 'Nama', 'username' => 'dipakai'])
            ->assertSessionHasErrors(['username' => 'Username sudah digunakan.']);

        $this->assertSame('saya', $user->refresh()->username);
    }

    public function test_required_fields_and_username_format_are_validated(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->from('/profile')
            ->put('/profile', ['name' => '', 'username' => 'nama pengguna'])
            ->assertSessionHasErrors(['name' => 'Nama wajib diisi.', 'username']);
    }

    public function test_the_password_can_be_changed(): void
    {
        $user = User::factory()->create(['password' => 'password-lama']);

        $this->actingAs($user)
            ->put('/profile', [
                'name' => $user->name,
                'username' => $user->username,
                'password' => 'password-baru',
                'password_confirmation' => 'password-baru',
            ])
            ->assertSessionHasNoErrors();

        $this->assertTrue(Hash::check('password-baru', $user->refresh()->password));
    }

    public function test_a_blank_password_keeps_the_old_one(): void
    {
        $user = User::factory()->create(['password' => 'password-lama']);

        $this->actingAs($user)
            ->put('/profile', ['name' => 'Nama', 'username' => $user->username, 'password' => ''])
            ->assertSessionHasNoErrors();

        $this->assertTrue(Hash::check('password-lama', $user->refresh()->password));
    }

    public function test_the_new_password_must_be_confirmed_and_long_enough(): void
    {
        $user = User::factory()->create(['password' => 'password-lama']);
        $base = ['name' => $user->name, 'username' => $user->username];

        $this->actingAs($user)->from('/profile')
            ->put('/profile', $base + ['password' => 'password-baru', 'password_confirmation' => 'berbeda'])
            ->assertSessionHasErrors('password');

        $this->from('/profile')
            ->put('/profile', $base + ['password' => 'pendek', 'password_confirmation' => 'pendek'])
            ->assertSessionHasErrors('password');

        $this->assertTrue(Hash::check('password-lama', $user->refresh()->password));
    }

    public function test_a_photo_can_be_uploaded_and_replaced(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->put('/profile', [
                'name' => $user->name,
                'username' => $user->username,
                'photo' => UploadedFile::fake()->image('satu.jpg', 200, 200),
            ])
            ->assertSessionHasNoErrors();

        $first = (string) $user->refresh()->profile_photo_path;

        $this->assertStringStartsWith('profile-photos/', $first);
        Storage::disk('public')->assertExists($first);

        $this->put('/profile', [
            'name' => $user->name,
            'username' => $user->username,
            'photo' => UploadedFile::fake()->image('dua.png', 200, 200),
        ]);

        $second = (string) $user->refresh()->profile_photo_path;

        Storage::disk('public')->assertMissing($first);
        Storage::disk('public')->assertExists($second);
    }

    public function test_the_photo_can_be_removed(): void
    {
        Storage::disk('public')->put('profile-photos/lama.jpg', 'x');
        $user = User::factory()->create(['profile_photo_path' => 'profile-photos/lama.jpg']);

        $this->actingAs($user)
            ->put('/profile', ['name' => $user->name, 'username' => $user->username, 'remove_photo' => 1])
            ->assertSessionHasNoErrors();

        $this->assertNull($user->refresh()->profile_photo_path);
        Storage::disk('public')->assertMissing('profile-photos/lama.jpg');
    }

    public function test_invalid_photos_are_rejected(): void
    {
        $user = User::factory()->create();
        $base = ['name' => $user->name, 'username' => $user->username];

        $this->actingAs($user);

        foreach ([
            UploadedFile::fake()->create('dokumen.pdf', 10, 'application/pdf'),
            UploadedFile::fake()->image('animasi.gif'),
            UploadedFile::fake()->image('besar.jpg')->size(3000),
        ] as $file) {
            $this->from('/profile')
                ->put('/profile', $base + ['photo' => $file])
                ->assertSessionHasErrors('photo');
        }

        $this->assertNull($user->refresh()->profile_photo_path);
    }
}
'@

foreach ($f in @('tests/Feature/PublicPostTest.php', 'tests/Feature/ProfileTest.php')) {
  php -l $f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: sintaks PHP salah di $f" -ForegroundColor Red
    php -l $f
    exit 1
  }
}
Write-Host "Lint PHP: semua file valid." -ForegroundColor Green

Write-Host ""
Write-Host "FASE 5c2 SELESAI." -ForegroundColor Green