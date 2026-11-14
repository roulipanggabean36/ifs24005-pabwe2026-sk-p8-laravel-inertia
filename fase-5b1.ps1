# fase-5b1.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path 'tests/TestCase.php')) {
  Write-Host "GAGAL: jalankan fase-5a.ps1 dulu." -ForegroundColor Red
  exit 1
}

W 'tests/Unit/PostServiceTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Models\Post;
use App\Features\Post\Services\PostService;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

final class PostServiceTest extends TestCase
{
    use RefreshDatabase;

    private PostService $service;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
        $this->service = $this->app->make(PostService::class);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function data(array $overrides = []): array
    {
        return array_merge([
            'title' => 'Judul Artikel',
            'category' => 'Umum',
            'content' => 'Isi artikel',
        ], $overrides);
    }

    public function test_create_builds_slug_excerpt_and_publication_state(): void
    {
        $user = User::factory()->create();

        $post = $this->service->create($user, $this->data([
            'title' => 'Halo Dunia',
            'content' => "## Judul\n\nIsi **tebal** artikel",
            'is_published' => true,
        ]));

        $this->assertSame('halo-dunia', $post->slug);
        $this->assertSame('Judul Isi tebal artikel', $post->excerpt);
        $this->assertTrue($post->is_published);
        $this->assertNotNull($post->published_at);
        $this->assertTrue($post->user->is($user));
    }

    public function test_create_without_publish_flag_makes_a_draft(): void
    {
        $post = $this->service->create(User::factory()->create(), $this->data());

        $this->assertFalse($post->is_published);
        $this->assertNull($post->published_at);
    }

    public function test_create_truncates_a_long_generated_excerpt(): void
    {
        $post = $this->service->create(
            User::factory()->create(),
            $this->data(['content' => str_repeat('a', 400)]),
        );

        $this->assertSame(163, strlen($post->excerpt));
        $this->assertStringEndsWith('...', $post->excerpt);
    }

    public function test_create_keeps_a_given_excerpt_trimmed(): void
    {
        $post = $this->service->create(
            User::factory()->create(),
            $this->data(['excerpt' => '  Ringkas  ']),
        );

        $this->assertSame('Ringkas', $post->excerpt);
    }

    public function test_create_uses_an_explicit_published_at(): void
    {
        $post = $this->service->create(User::factory()->create(), $this->data([
            'is_published' => true,
            'published_at' => '2026-01-02 03:04:05',
        ]));

        $this->assertSame('2026-01-02 03:04:05', $post->published_at->format('Y-m-d H:i:s'));
    }

    public function test_create_generates_unique_slugs(): void
    {
        $user = User::factory()->create();

        $slugs = [];

        foreach (range(1, 3) as $ignored) {
            $slugs[] = $this->service->create($user, $this->data(['title' => 'Sama']))->slug;
        }

        $this->assertSame(['sama', 'sama-2', 'sama-3'], $slugs);
    }

    public function test_create_handles_titles_without_slug_characters(): void
    {
        $user = User::factory()->create();

        $first = $this->service->create($user, $this->data(['title' => '!!!']));
        $second = $this->service->create($user, $this->data(['title' => '???']));

        $this->assertSame('artikel', $first->slug);
        $this->assertSame('artikel-2', $second->slug);
    }

    public function test_create_limits_the_slug_length(): void
    {
        $post = $this->service->create(
            User::factory()->create(),
            $this->data(['title' => str_repeat('a', 250)]),
        );

        $this->assertSame(200, strlen($post->slug));
    }

    public function test_create_stores_the_cover_image(): void
    {
        $post = $this->service->create(
            User::factory()->create(),
            $this->data(),
            UploadedFile::fake()->image('c.jpg'),
        );

        $this->assertStringStartsWith('covers/', (string) $post->cover_image_path);
        Storage::disk('public')->assertExists((string) $post->cover_image_path);
    }

    public function test_update_keeps_the_slug_when_the_title_is_unchanged(): void
    {
        $post = Post::factory()->create(['title' => 'Tetap', 'slug' => 'tetap-slug']);

        $updated = $this->service->update($post, $this->data(['title' => 'Tetap', 'content' => 'baru']));

        $this->assertSame('tetap-slug', $updated->slug);
        $this->assertSame('baru', $updated->content);
    }

    public function test_update_changes_the_slug_when_the_title_changes(): void
    {
        $post = Post::factory()->create(['slug' => 'lama']);

        $updated = $this->service->update($post, $this->data(['title' => 'Judul Baru']));

        $this->assertSame('judul-baru', $updated->slug);

        Post::factory()->create(['slug' => 'kembar']);
        $other = Post::factory()->create(['slug' => 'lain']);

        $this->assertSame('kembar-2', $this->service->update($other, $this->data(['title' => 'Kembar']))->slug);
    }

    public function test_update_resolves_the_excerpt_from_content(): void
    {
        $post = Post::factory()->create();

        $updated = $this->service->update($post, $this->data(['content' => 'Isi baru sekali']));

        $this->assertSame('Isi baru sekali', $updated->excerpt);
    }

    public function test_update_applies_the_publish_flag(): void
    {
        $draft = Post::factory()->draft()->create();

        $published = $this->service->update($draft, $this->data(['is_published' => true]));

        $this->assertTrue($published->is_published);
        $this->assertNotNull($published->published_at);

        $back = $this->service->update($published, $this->data(['is_published' => false]));

        $this->assertFalse($back->is_published);
        $this->assertNull($back->published_at);
    }

    public function test_update_preserves_an_existing_published_at(): void
    {
        $post = Post::factory()->create(['published_at' => '2026-01-01 00:00:00']);

        $updated = $this->service->update($post, $this->data(['is_published' => true]));

        $this->assertSame('2026-01-01', $updated->published_at->format('Y-m-d'));
    }

    public function test_update_without_the_flag_keeps_the_publication_state(): void
    {
        $post = Post::factory()->create();

        $updated = $this->service->update($post, $this->data());

        $this->assertTrue($updated->is_published);
        $this->assertNotNull($updated->published_at);
    }

    public function test_delete_removes_the_post_and_its_cover(): void
    {
        Storage::disk('public')->put('covers/a.jpg', 'x');
        $post = Post::factory()->create(['cover_image_path' => 'covers/a.jpg']);

        $this->service->delete($post);

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
        Storage::disk('public')->assertMissing('covers/a.jpg');
    }

    public function test_delete_works_without_a_cover(): void
    {
        $post = Post::factory()->create(['cover_image_path' => null]);

        $this->service->delete($post);

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
    }

    public function test_toggle_publish_flips_the_state(): void
    {
        $post = Post::factory()->draft()->create();

        $on = $this->service->togglePublish($post);

        $this->assertTrue($on->is_published);
        $this->assertNotNull($on->published_at);

        $off = $this->service->togglePublish($on);

        $this->assertFalse($off->is_published);
        $this->assertNull($off->published_at);
    }

    public function test_upload_cover_replaces_the_previous_file(): void
    {
        Storage::disk('public')->put('covers/lama.jpg', 'x');
        $post = Post::factory()->create(['cover_image_path' => 'covers/lama.jpg']);

        $updated = $this->service->uploadCover($post, UploadedFile::fake()->image('baru.jpg'));

        Storage::disk('public')->assertMissing('covers/lama.jpg');
        Storage::disk('public')->assertExists((string) $updated->cover_image_path);
        $this->assertNotSame('covers/lama.jpg', $updated->cover_image_path);
    }

    public function test_remove_cover_deletes_the_file_and_is_safe_to_repeat(): void
    {
        Storage::disk('public')->put('covers/a.jpg', 'x');
        $post = Post::factory()->create(['cover_image_path' => 'covers/a.jpg']);

        $updated = $this->service->removeCover($post);

        $this->assertNull($updated->cover_image_path);
        Storage::disk('public')->assertMissing('covers/a.jpg');
        $this->assertNull($this->service->removeCover($updated)->cover_image_path);
    }

    public function test_create_many_saves_drafts(): void
    {
        $user = User::factory()->create();

        $count = $this->service->createMany($user, [
            ['title' => 'Satu', 'category' => 'Umum', 'excerpt' => 'r', 'content' => 'isi'],
            ['title' => 'Dua', 'category' => 'Bisnis', 'content' => 'isi'],
        ]);

        $this->assertSame(2, $count);
        $this->assertSame(
            2,
            Post::query()->where('user_id', $user->id)->where('is_published', false)->count(),
        );
    }

    public function test_create_many_rolls_back_when_an_item_fails(): void
    {
        $user = User::factory()->create();

        try {
            $this->service->createMany($user, [
                ['title' => 'Valid', 'category' => 'Umum', 'content' => 'isi'],
                ['title' => 'Rusak', 'category' => null, 'content' => 'isi'],
            ]);

            $this->fail('QueryException seharusnya dilempar.');
        } catch (QueryException) {
            $this->assertSame(0, Post::query()->count());
        }
    }

    public function test_listing_helpers_delegate_to_the_repository(): void
    {
        $user = User::factory()->create();
        $published = Post::factory()->create(['user_id' => $user->id, 'slug' => 'terbit-satu']);
        Post::factory()->draft()->create(['user_id' => $user->id]);

        $this->assertSame(1, $this->service->listPublic(null, null)->total());
        $this->assertTrue($this->service->findPublished('terbit-satu')->is($published));
        $this->assertNull($this->service->findPublished('tidak-ada'));
        $this->assertSame(2, $this->service->listForUser($user->id, null, null, null)->total());
        $this->assertSame(2, $this->service->listAll(null, null, null)->total());
        $this->assertSame(
            ['total' => 2, 'published' => 1, 'draft' => 1],
            $this->service->statsForUser($user->id),
        );
        $this->assertCount(2, $this->service->exportForUser($user->id));
        $this->assertCount(2, $this->service->exportAll());
    }
}
'@

W 'tests/Unit/ProfileServiceTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Profile\Services\ProfileService;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

final class ProfileServiceTest extends TestCase
{
    use RefreshDatabase;

    private ProfileService $service;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
        $this->service = new ProfileService();
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function user(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'name' => 'Nama Lama',
            'username' => 'lama',
            'password' => 'password-lama',
        ], $overrides));
    }

    public function test_it_updates_identity_and_keeps_the_password_when_blank(): void
    {
        $user = $this->user();

        foreach ([[], ['password' => null], ['password' => '']] as $extra) {
            $updated = $this->service->update($user, ['name' => 'Nama Baru', 'username' => 'baru'] + $extra);

            $this->assertSame('Nama Baru', $updated->name);
            $this->assertSame('baru', $updated->username);
            $this->assertTrue(Hash::check('password-lama', $updated->password));
        }
    }

    public function test_it_changes_the_password(): void
    {
        $user = $this->user();

        $updated = $this->service->update($user, [
            'name' => 'Nama Lama',
            'username' => 'lama',
            'password' => 'password-baru',
        ]);

        $this->assertTrue(Hash::check('password-baru', $updated->password));
        $this->assertFalse(Hash::check('password-lama', $updated->password));
    }

    public function test_it_uploads_a_photo(): void
    {
        $user = $this->user();

        $updated = $this->service->update(
            $user,
            ['name' => 'Nama Lama', 'username' => 'lama'],
            UploadedFile::fake()->image('foto.jpg'),
        );

        $this->assertStringStartsWith('profile-photos/', (string) $updated->profile_photo_path);
        Storage::disk('public')->assertExists((string) $updated->profile_photo_path);
    }

    public function test_it_replaces_an_existing_photo(): void
    {
        Storage::disk('public')->put('profile-photos/lama.jpg', 'x');
        $user = $this->user(['profile_photo_path' => 'profile-photos/lama.jpg']);

        $updated = $this->service->update(
            $user,
            ['name' => 'Nama Lama', 'username' => 'lama'],
            UploadedFile::fake()->image('baru.jpg'),
        );

        Storage::disk('public')->assertMissing('profile-photos/lama.jpg');
        Storage::disk('public')->assertExists((string) $updated->profile_photo_path);
    }

    public function test_a_new_photo_wins_over_the_remove_flag(): void
    {
        $user = $this->user();

        $updated = $this->service->update(
            $user,
            ['name' => 'Nama Lama', 'username' => 'lama'],
            UploadedFile::fake()->image('baru.jpg'),
            true,
        );

        $this->assertNotNull($updated->profile_photo_path);
    }

    public function test_it_removes_the_photo(): void
    {
        Storage::disk('public')->put('profile-photos/lama.jpg', 'x');
        $user = $this->user(['profile_photo_path' => 'profile-photos/lama.jpg']);

        $updated = $this->service->update($user, ['name' => 'Nama Lama', 'username' => 'lama'], null, true);

        $this->assertNull($updated->profile_photo_path);
        Storage::disk('public')->assertMissing('profile-photos/lama.jpg');
    }

    public function test_remove_flag_without_a_photo_is_harmless(): void
    {
        $user = $this->user();

        $updated = $this->service->update($user, ['name' => 'Nama Lama', 'username' => 'lama'], null, true);

        $this->assertNull($updated->profile_photo_path);
    }

    public function test_it_leaves_the_photo_untouched_by_default(): void
    {
        Storage::disk('public')->put('profile-photos/lama.jpg', 'x');
        $user = $this->user(['profile_photo_path' => 'profile-photos/lama.jpg']);

        $updated = $this->service->update($user, ['name' => 'Nama Lama', 'username' => 'lama']);

        $this->assertSame('profile-photos/lama.jpg', $updated->profile_photo_path);
        Storage::disk('public')->assertExists('profile-photos/lama.jpg');
    }
}
'@

W 'tests/Unit/AdminUserServiceTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Admin\Services\AdminUserService;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class AdminUserServiceTest extends TestCase
{
    use RefreshDatabase;

    private AdminUserService $service;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = $this->app->make(AdminUserService::class);
    }

    public function test_users_are_ordered_by_name_with_post_counts(): void
    {
        $budi = User::factory()->create(['name' => 'Budi', 'username' => 'budi']);
        $ani = User::factory()->create(['name' => 'Ani', 'username' => 'ani']);
        Post::factory()->count(2)->create(['user_id' => $ani->id]);

        $items = $this->service->listUsers(null)->items();

        $this->assertSame(['Ani', 'Budi'], [$items[0]->name, $items[1]->name]);
        $this->assertEquals(2, $items[0]->posts_count);
        $this->assertEquals(0, $items[1]->posts_count);
    }

    public function test_search_matches_name_or_username_case_insensitively(): void
    {
        User::factory()->create(['name' => 'Siti Aminah', 'username' => 'siti']);
        User::factory()->create(['name' => 'Joko', 'username' => 'penulis-joko']);
        User::factory()->create(['name' => 'Rina', 'username' => 'rina']);

        $byName = $this->service->listUsers('AMINAH')->items();
        $byUsername = $this->service->listUsers('PENULIS')->items();

        $this->assertSame(['Siti Aminah'], array_map(fn ($user) => $user->name, $byName));
        $this->assertSame(['Joko'], array_map(fn ($user) => $user->name, $byUsername));
    }

    public function test_search_treats_wildcards_literally(): void
    {
        User::factory()->create(['name' => 'Tes 100%', 'username' => 'u1']);
        User::factory()->create(['name' => 'Tes 1000', 'username' => 'u2']);

        $items = $this->service->listUsers('100%')->items();

        $this->assertSame(['Tes 100%'], array_map(fn ($user) => $user->name, $items));
    }

    public function test_blank_search_returns_everyone_and_paginates(): void
    {
        foreach (range(1, 11) as $number) {
            User::factory()->create(['name' => 'Pengguna '.$number, 'username' => 'pengguna'.$number]);
        }

        $page = $this->service->listUsers('   ');

        $this->assertSame(11, $page->total());
        $this->assertCount(10, $page->items());
        $this->assertSame(2, $page->lastPage());
    }

    public function test_it_lists_posts_and_stats_for_one_user(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->draft()->create(['user_id' => $user->id]);
        Post::factory()->create();

        $this->assertSame(3, $this->service->postsForUser($user, null, null, null)->total());
        $this->assertSame(1, $this->service->postsForUser($user, null, null, 'draft')->total());
        $this->assertSame(
            ['total' => 3, 'published' => 2, 'draft' => 1],
            $this->service->statsForUser($user),
        );
    }

    public function test_it_exports_the_posts_of_one_user(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->create();

        $this->assertCount(2, $this->service->exportForUser($user));
    }
}
'@

foreach ($f in @('tests/Unit/PostServiceTest.php', 'tests/Unit/ProfileServiceTest.php', 'tests/Unit/AdminUserServiceTest.php')) {
  php -l $f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: sintaks PHP salah di $f" -ForegroundColor Red
    php -l $f
    exit 1
  }
}
Write-Host "Lint PHP: semua file valid." -ForegroundColor Green

Write-Host ""
Write-Host "FASE 5b1 SELESAI." -ForegroundColor Green