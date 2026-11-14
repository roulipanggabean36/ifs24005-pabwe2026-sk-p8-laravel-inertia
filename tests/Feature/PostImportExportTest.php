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