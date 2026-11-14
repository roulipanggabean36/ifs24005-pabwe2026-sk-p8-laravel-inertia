# fase-5d2.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path 'tests/Feature/DashboardPostTest.php')) {
  Write-Host "GAGAL: jalankan fase-5d1.ps1 dulu." -ForegroundColor Red
  exit 1
}

W 'tests/Support/ReadsDownloads.php' @'
<?php

declare(strict_types=1);

namespace Tests\Support;

use Illuminate\Testing\TestResponse;
use PhpOffice\PhpSpreadsheet\IOFactory;

trait ReadsDownloads
{
    /**
     * Baca isi unduhan Excel (termasuk baris header) dari response streaming.
     *
     * @return array<int, array<int, mixed>>
     */
    protected function spreadsheetRows(TestResponse $response): array
    {
        $path = (string) tempnam(sys_get_temp_dir(), 'blogdl');
        file_put_contents($path, $response->streamedContent());

        $rows = IOFactory::load($path)->getActiveSheet()->toArray(null, true, true, false);

        unlink($path);

        return $rows;
    }
}
'@

W 'tests/Feature/PostImportExportTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\Support\BuildsSpreadsheets;
use Tests\Support\ReadsDownloads;
use Tests\TestCase;

final class PostImportExportTest extends TestCase
{
    use BuildsSpreadsheets;
    use ReadsDownloads;
    use RefreshDatabase;

    private User $member;

    protected function setUp(): void
    {
        parent::setUp();

        $this->member = User::factory()->create();
        $this->actingAs($this->member);
    }

    public function test_export_downloads_only_own_posts(): void
    {
        Post::factory()->create(['user_id' => $this->member->id, 'title' => 'Milik Saya']);
        Post::factory()->create(['title' => 'Milik Orang Lain']);

        $response = $this->get('/dashboard/posts/export');

        $response->assertOk()->assertDownload();
        $this->assertStringContainsString('artikel-saya-', (string) $response->headers->get('Content-Disposition'));

        $rows = $this->spreadsheetRows($response);

        $this->assertCount(2, $rows);
        $this->assertSame('Judul', $rows[0][0]);
        $this->assertNotContains('Penulis', $rows[0]);
        $this->assertSame('Milik Saya', $rows[1][0]);
    }

    public function test_import_creates_the_posts_of_the_member(): void
    {
        $this->post('/dashboard/posts/import', ['file' => $this->xlsxUpload([
            ['Judul', 'Kategori', 'Isi', 'Status'],
            ['Satu', 'Umum', 'Isi satu', 'Terbit'],
            ['Dua', 'Bisnis', 'Isi dua', 'Draf'],
        ])])
            ->assertRedirect(route('dashboard.posts.index'))
            ->assertSessionHas('success', '2 artikel berhasil diimpor.')
            ->assertSessionMissing('import_errors')
            ->assertSessionMissing('error');

        $this->assertSame(2, $this->member->posts()->count());
        $this->assertSame(1, $this->member->posts()->where('is_published', true)->count());
    }

    public function test_import_reports_the_rows_that_failed(): void
    {
        $this->post('/dashboard/posts/import', ['file' => $this->xlsxUpload([
            ['Judul', 'Kategori', 'Isi'],
            ['Valid', 'Umum', 'isi'],
            ['', 'Umum', 'isi'],
        ])])
            ->assertRedirect(route('dashboard.posts.index'))
            ->assertSessionHas('success', '1 artikel berhasil diimpor.')
            ->assertSessionHas('import_errors', fn (array $errors): bool => count($errors) === 1 && $errors[0]['row'] === 3);

        $this->assertSame(1, Post::query()->count());
    }

    public function test_import_with_nothing_valid_shows_an_error(): void
    {
        $this->post('/dashboard/posts/import', ['file' => $this->xlsxUpload([
            ['Judul', 'Kategori', 'Isi'],
            ['', 'Umum', 'isi'],
        ])])
            ->assertRedirect(route('dashboard.posts.index'))
            ->assertSessionHas('error', 'Tidak ada artikel yang berhasil diimpor.')
            ->assertSessionHas('import_errors')
            ->assertSessionMissing('success');

        $this->assertSame(0, Post::query()->count());
    }

    public function test_import_reports_missing_columns(): void
    {
        $this->post('/dashboard/posts/import', ['file' => $this->xlsxUpload([['Judul'], ['A']])])
            ->assertSessionHas('error')
            ->assertSessionHas('import_errors', fn (array $errors): bool => str_contains($errors[0]['message'], 'Kategori, Isi'));
    }

    public function test_import_validates_the_uploaded_file(): void
    {
        $this->post('/dashboard/posts/import', [])->assertSessionHasErrors('file');

        $this->post('/dashboard/posts/import', [
            'file' => UploadedFile::fake()->create('dokumen.pdf', 10, 'application/pdf'),
        ])->assertSessionHasErrors('file');

        $this->post('/dashboard/posts/import', [
            'file' => UploadedFile::fake()->create('besar.xlsx', 6000),
        ])->assertSessionHasErrors('file');

        $this->assertSame(0, Post::query()->count());
    }
}
'@

W 'tests/Feature/AiPostTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Ai\Contracts\AiClientInterface;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\FakeAiClient;
use Tests\TestCase;

final class AiPostTest extends TestCase
{
    use RefreshDatabase;

    private User $member;

    protected function setUp(): void
    {
        parent::setUp();

        $this->member = User::factory()->create();
        $this->actingAs($this->member);
    }

    private function fakeAi(AiClientInterface $client): void
    {
        $this->app->instance(AiClientInterface::class, $client);
    }

    public function test_generate_returns_articles_without_saving_them(): void
    {
        $fake = FakeAiClient::withArticles([
            ['title' => 'Artikel AI Satu', 'category' => 'Teknologi', 'excerpt' => 'Ringkas', 'content' => '## Isi satu'],
            ['title' => 'Artikel AI Dua', 'category' => 'astronomi', 'excerpt' => '', 'content' => 'Isi dua'],
        ]);
        $this->fakeAi($fake);

        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'Laravel', 'count' => 2])
            ->assertOk()
            ->assertJsonCount(2, 'items')
            ->assertJsonPath('items.0.title', 'Artikel AI Satu')
            ->assertJsonPath('items.1.category', 'Umum');

        $this->assertDatabaseCount('posts', 0);
        $this->assertCount(1, $fake->calls);
        $this->assertStringContainsString('Laravel', $fake->calls[0]['user']);
    }

    public function test_generate_accepts_the_boundary_counts(): void
    {
        $this->fakeAi(FakeAiClient::withArticles([
            ['title' => 'A', 'category' => 'Umum', 'content' => 'isi'],
        ]));

        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'x', 'count' => 1])->assertOk();
        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'x', 'count' => 10])->assertOk();
    }

    public function test_generate_shows_friendly_errors_from_the_ai(): void
    {
        $this->fakeAi(FakeAiClient::failing('Layanan AI sedang gangguan'));

        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'Laravel', 'count' => 2])
            ->assertStatus(422)
            ->assertExactJson(['message' => 'Layanan AI sedang gangguan']);

        $this->fakeAi(FakeAiClient::returning('bukan json'));

        $this->postJson('/dashboard/posts/ai-generate', ['topic' => 'Laravel', 'count' => 2])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Respons AI tidak dapat dibaca. Silakan coba lagi.');
    }

    public function test_generate_validates_topic_and_count(): void
    {
        $fake = new FakeAiClient();
        $this->fakeAi($fake);
        $url = '/dashboard/posts/ai-generate';

        $this->postJson($url, [])->assertJsonValidationErrors(['topic', 'count']);
        $this->postJson($url, ['topic' => str_repeat('a', 201), 'count' => 2])->assertJsonValidationErrors('topic');

        foreach ([0, 11, 'abc', 2.5] as $count) {
            $this->postJson($url, ['topic' => 'Laravel', 'count' => $count])->assertJsonValidationErrors('count');
        }

        $this->assertCount(0, $fake->calls);
    }

    public function test_save_stores_the_selected_articles_as_drafts(): void
    {
        $this->post('/dashboard/posts/ai-save', ['items' => [
            ['title' => 'AI Satu', 'category' => 'Teknologi', 'excerpt' => 'Ringkas', 'content' => 'Isi satu'],
            ['title' => 'AI Dua', 'category' => 'Bisnis', 'content' => 'Isi dua'],
        ]])
            ->assertRedirect(route('dashboard.posts.index'))
            ->assertSessionHas('success', '2 artikel hasil AI disimpan sebagai draf.');

        $this->assertSame(2, $this->member->posts()->where('is_published', false)->count());
        $this->assertDatabaseHas('posts', ['slug' => 'ai-satu', 'excerpt' => 'Ringkas']);
        $this->assertDatabaseHas('posts', ['slug' => 'ai-dua', 'excerpt' => 'Isi dua']);
    }

    public function test_save_validates_the_items(): void
    {
        $item = ['title' => 'AI', 'category' => 'Umum', 'content' => 'isi'];

        $this->post('/dashboard/posts/ai-save', [])->assertSessionHasErrors('items');
        $this->post('/dashboard/posts/ai-save', ['items' => []])->assertSessionHasErrors('items');
        $this->post('/dashboard/posts/ai-save', ['items' => array_fill(0, 11, $item)])->assertSessionHasErrors('items');
        $this->post('/dashboard/posts/ai-save', ['items' => [['category' => 'Umum', 'content' => 'isi']]])
            ->assertSessionHasErrors('items.0.title');
        $this->post('/dashboard/posts/ai-save', ['items' => [$item + ['category' => 'Astronomi']]])
            ->assertSessionHasErrors('items.0.category');
        $this->post('/dashboard/posts/ai-save', ['items' => [['title' => 'AI', 'category' => 'Umum']]])
            ->assertSessionHasErrors('items.0.content');

        $this->assertSame(0, Post::query()->count());
    }
}
'@

W 'tests/Feature/AdminTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\Support\ReadsDownloads;
use Tests\TestCase;

final class AdminTest extends TestCase
{
    use ReadsDownloads;
    use RefreshDatabase;

    private User $admin;

    private User $writer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->admin()->create(['name' => 'Admin Utama', 'username' => 'adminutama']);
        $this->writer = User::factory()->create(['name' => 'Zaki', 'username' => 'zaki']);
        $this->actingAs($this->admin);
    }

    public function test_user_list_shows_post_counts(): void
    {
        Post::factory()->count(2)->create(['user_id' => $this->writer->id]);

        $this->get('/admin/users')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Admin/UserList')
            ->where('users.total', 2)
            ->where('users.data.0.name', 'Admin Utama')
            ->where('users.data.0.role', 'admin')
            ->where('users.data.1.name', 'Zaki')
            ->where('users.data.1.posts_count', fn ($count) => (int) $count === 2)
            ->where('users.data.1.photo_url', null)
            ->missing('users.data.1.password')
            ->where('filters.search', ''));
    }

    public function test_user_list_can_be_searched(): void
    {
        $this->get('/admin/users?search=zaki')->assertInertia(fn (Assert $page) => $page
            ->has('users.data', 1)
            ->where('users.data.0.username', 'zaki')
            ->where('filters.search', 'zaki'));

        $this->get('/admin/users?search='.str_repeat('a', 101))->assertSessionHasErrors('search');
    }

    public function test_user_posts_page_is_monitoring_for_one_user(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki']);
        Post::factory()->draft()->create(['user_id' => $this->writer->id, 'title' => 'Draf Zaki']);
        Post::factory()->create(['title' => 'Orang Lain']);

        $this->get("/admin/users/{$this->writer->id}/posts")->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Admin/UserPostList')
            ->where('owner', ['id' => $this->writer->id, 'name' => 'Zaki', 'username' => 'zaki'])
            ->where('posts.total', 2)
            ->where('stats', ['total' => 2, 'published' => 1, 'draft' => 1])
            ->where('filters', ['search' => '', 'category' => '', 'status' => ''])
            ->has('categories', 6));
    }

    public function test_user_posts_page_supports_filters(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki', 'category' => 'Bisnis', 'content' => 'a']);
        Post::factory()->draft()->create(['user_id' => $this->writer->id, 'title' => 'Draf Zaki', 'category' => 'Umum', 'content' => 'b']);
        $base = "/admin/users/{$this->writer->id}/posts";

        $this->get($base.'?status=draft')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Draf Zaki'));
        $this->get($base.'?search=terbit')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Terbit Zaki'));
        $this->get($base.'?category=Umum')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Draf Zaki'));
        $this->get($base.'?status=weird')->assertSessionHasErrors('status');
    }

    public function test_unknown_users_are_not_found(): void
    {
        $this->get('/admin/users/999999/posts')->assertNotFound();
        $this->get('/admin/users/abc/posts')->assertNotFound();
        $this->get('/admin/users/999999/posts/export')->assertNotFound();
    }

    public function test_one_users_posts_can_be_exported(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki']);
        Post::factory()->create(['title' => 'Orang Lain']);

        $response = $this->get("/admin/users/{$this->writer->id}/posts/export");

        $response->assertOk()->assertDownload();
        $this->assertStringContainsString('artikel-zaki-', (string) $response->headers->get('Content-Disposition'));

        $rows = $this->spreadsheetRows($response);

        $this->assertCount(2, $rows);
        $this->assertSame('Penulis', $rows[0][7]);
        $this->assertSame('Terbit Zaki', $rows[1][0]);
        $this->assertSame('Zaki', $rows[1][7]);
    }

    public function test_all_posts_page_lists_every_post_with_the_author(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki']);
        Post::factory()->draft()->create(['user_id' => $this->admin->id, 'title' => 'Draf Admin']);

        $this->get('/admin/posts')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Admin/PostList')
            ->where('posts.total', 2)
            ->where('posts.data.0.title', 'Draf Admin')
            ->where('posts.data.0.author', 'Admin Utama')
            ->where('posts.data.0.author_username', 'adminutama')
            ->where('posts.data.1.author', 'Zaki')
            ->where('filters', ['search' => '', 'category' => '', 'status' => ''])
            ->has('categories', 6));
    }

    public function test_all_posts_page_supports_filters(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id, 'title' => 'Terbit Zaki', 'category' => 'Bisnis', 'content' => 'a']);
        Post::factory()->draft()->create(['user_id' => $this->admin->id, 'title' => 'Draf Admin', 'category' => 'Umum', 'content' => 'b']);

        $this->get('/admin/posts?status=draft')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Draf Admin'));
        $this->get('/admin/posts?category=Bisnis')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('posts.data.0.title', 'Terbit Zaki'));
        $this->get('/admin/posts?search=admin')->assertInertia(fn (Assert $page) => $page
            ->has('posts.data', 1)->where('filters.search', 'admin'));
        $this->get('/admin/posts?status=weird')->assertSessionHasErrors('status');
    }

    public function test_every_post_can_be_exported(): void
    {
        Post::factory()->create(['user_id' => $this->writer->id]);
        Post::factory()->draft()->create(['user_id' => $this->admin->id]);

        $response = $this->get('/admin/posts/export');

        $response->assertOk()->assertDownload();
        $this->assertStringContainsString('semua-artikel-', (string) $response->headers->get('Content-Disposition'));

        $rows = $this->spreadsheetRows($response);

        $this->assertCount(3, $rows);
        $this->assertSame('Penulis', $rows[0][7]);
    }

    public function test_the_admin_panel_never_changes_posts(): void
    {
        $post = Post::factory()->create(['user_id' => $this->writer->id]);

        $this->put("/dashboard/posts/{$post->id}", ['title' => 'x', 'category' => 'Umum', 'content' => 'y'])->assertForbidden();
        $this->delete("/dashboard/posts/{$post->id}")->assertForbidden();

        $this->assertDatabaseHas('posts', ['id' => $post->id, 'title' => $post->title]);
    }
}
'@

foreach ($f in @('tests/Support/ReadsDownloads.php', 'tests/Feature/PostImportExportTest.php', 'tests/Feature/AiPostTest.php', 'tests/Feature/AdminTest.php')) {
  php -l $f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: sintaks PHP salah di $f" -ForegroundColor Red
    php -l $f
    exit 1
  }
}
Write-Host "Lint PHP: semua file valid." -ForegroundColor Green

Write-Host ""
Write-Host "FASE 5d2 SELESAI." -ForegroundColor Green