<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Models\Post;
use App\Features\Post\Services\PostExcelService;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Tests\Support\BuildsSpreadsheets;
use Tests\TestCase;

final class PostExcelServiceTest extends TestCase
{
    use BuildsSpreadsheets;
    use RefreshDatabase;

    private PostExcelService $service;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = $this->app->make(PostExcelService::class);
    }

    /**
     * @return Collection<int, Post>
     */
    private function posts(): Collection
    {
        return Post::query()->with('user')->orderBy('id')->get();
    }

    /**
     * @return list<string>
     */
    private function header(): array
    {
        return ['Judul', 'Kategori', 'Isi', 'Ringkasan', 'Status', 'Tanggal Publikasi'];
    }

    public function test_spreadsheet_has_bold_headers_and_one_row_per_post(): void
    {
        $user = User::factory()->create();
        Post::factory()->create([
            'user_id' => $user->id,
            'title' => 'Judul Satu',
            'slug' => 'judul-satu',
            'category' => 'Bisnis',
            'excerpt' => 'Ringkas',
            'content' => 'Isi satu',
            'is_published' => true,
            'published_at' => '2026-02-03 04:05:06',
        ]);
        Post::factory()->draft()->create(['user_id' => $user->id, 'title' => 'Judul Dua']);

        $sheet = $this->service->buildSpreadsheet($this->posts(), false)->getActiveSheet();

        $this->assertSame('Artikel', $sheet->getTitle());
        $this->assertSame(
            ['Judul', 'Slug', 'Kategori', 'Ringkasan', 'Isi', 'Status', 'Tanggal Publikasi'],
            $sheet->rangeToArray('A1:G1')[0],
        );
        $this->assertTrue($sheet->getStyle('A1')->getFont()->getBold());
        $this->assertSame('G', $sheet->getHighestColumn());
        $this->assertSame(3, $sheet->getHighestRow());
        $this->assertSame('Judul Satu', $sheet->getCell('A2')->getValue());
        $this->assertSame('judul-satu', $sheet->getCell('B2')->getValue());
        $this->assertSame('Bisnis', $sheet->getCell('C2')->getValue());
        $this->assertSame('Terbit', $sheet->getCell('F2')->getValue());
        $this->assertSame('2026-02-03 04:05:06', $sheet->getCell('G2')->getValue());
        $this->assertSame('Draf', $sheet->getCell('F3')->getValue());
        $this->assertSame('', (string) $sheet->getCell('G3')->getValue());
    }

    public function test_admin_spreadsheet_adds_an_author_column(): void
    {
        $user = User::factory()->create(['name' => 'Penulis A']);
        Post::factory()->create(['user_id' => $user->id]);

        $sheet = $this->service->buildSpreadsheet($this->posts(), true)->getActiveSheet();

        $this->assertSame('H', $sheet->getHighestColumn());
        $this->assertSame('Penulis', $sheet->getCell('H1')->getValue());
        $this->assertSame('Penulis A', $sheet->getCell('H2')->getValue());
    }

    public function test_formula_like_content_is_written_as_text(): void
    {
        Post::factory()->create(['content' => '=SUM(1,2)']);

        $sheet = $this->service->buildSpreadsheet($this->posts(), false)->getActiveSheet();

        $this->assertSame('=SUM(1,2)', $sheet->getCell('E2')->getValue());
        $this->assertSame(DataType::TYPE_STRING, $sheet->getCell('E2')->getDataType());
    }

    public function test_content_column_has_a_fixed_width(): void
    {
        Post::factory()->create();

        $sheet = $this->service->buildSpreadsheet($this->posts(), false)->getActiveSheet();

        $this->assertEquals(60, $sheet->getColumnDimension('E')->getWidth());
        $this->assertFalse($sheet->getColumnDimension('E')->getAutoSize());
        $this->assertTrue($sheet->getColumnDimension('A')->getAutoSize());
    }

    public function test_empty_export_contains_only_the_header(): void
    {
        $sheet = $this->service->buildSpreadsheet(new Collection(), false)->getActiveSheet();

        $this->assertSame(1, $sheet->getHighestRow());
    }

    public function test_download_streams_an_xlsx_file(): void
    {
        Post::factory()->create();

        $response = $this->service->download($this->posts(), false, 'artikel.xlsx');

        $this->assertSame(
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            $response->headers->get('Content-Type'),
        );
        $this->assertStringContainsString('artikel.xlsx', (string) $response->headers->get('Content-Disposition'));

        ob_start();
        $response->sendContent();
        $binary = (string) ob_get_clean();

        $this->assertStringStartsWith('PK', $binary);
    }

    public function test_import_creates_posts_for_the_user(): void
    {
        $user = User::factory()->create();

        $result = $this->service->import($user, $this->xlsxUpload([
            $this->header(),
            ['Artikel Satu', 'Teknologi', 'Isi satu', 'Ringkas satu', 'Terbit', '2026-03-01 10:00:00'],
            ['Artikel Dua', 'Bisnis', 'Isi dua', '', 'Draf', ''],
        ]));

        $this->assertSame(['imported' => 2, 'errors' => []], $result);

        $one = Post::query()->where('title', 'Artikel Satu')->firstOrFail();
        $this->assertSame($user->id, $one->user_id);
        $this->assertTrue($one->is_published);
        $this->assertSame('2026-03-01', $one->published_at->format('Y-m-d'));
        $this->assertSame('Ringkas satu', $one->excerpt);
        $this->assertSame('artikel-satu', $one->slug);

        $two = Post::query()->where('title', 'Artikel Dua')->firstOrFail();
        $this->assertFalse($two->is_published);
        $this->assertNull($two->published_at);
        $this->assertSame('Isi dua', $two->excerpt);
    }

    public function test_import_reads_headers_case_insensitively_in_any_order(): void
    {
        $user = User::factory()->create();

        $result = $this->service->import($user, $this->xlsxUpload([
            ['isi', 'JUDUL', 'kategori', 'Tidak Dipakai'],
            ['Isi A', 'Judul A', 'umum', 'x'],
        ]));

        $this->assertSame(1, $result['imported']);
        $this->assertSame('Umum', Post::query()->where('title', 'Judul A')->value('category'));
    }

    public function test_import_normalizes_category_names(): void
    {
        $user = User::factory()->create();

        $this->service->import($user, $this->xlsxUpload([
            $this->header(),
            ['A', 'teknologi', 'isi', '', '', ''],
            ['B', 'GAYA HIDUP', 'isi', '', '', ''],
        ]));

        $this->assertSame('Teknologi', Post::query()->where('title', 'A')->value('category'));
        $this->assertSame('Gaya Hidup', Post::query()->where('title', 'B')->value('category'));
    }

    public function test_import_understands_status_values(): void
    {
        $user = User::factory()->create();

        $this->service->import($user, $this->xlsxUpload([
            $this->header(),
            ['S1', 'Umum', 'isi', '', 'published', ''],
            ['S2', 'Umum', 'isi', '', 'TERBIT', ''],
            ['S3', 'Umum', 'isi', '', 'draft', ''],
            ['S4', 'Umum', 'isi', '', '', ''],
        ]));

        $this->assertSame(2, Post::query()->where('is_published', true)->count());
        $this->assertSame(2, Post::query()->where('is_published', false)->count());
    }

    public function test_import_falls_back_to_now_for_missing_or_invalid_dates(): void
    {
        $user = User::factory()->create();

        $this->service->import($user, $this->xlsxUpload([
            $this->header(),
            ['D1', 'Umum', 'isi', '', 'Terbit', ''],
            ['D2', 'Umum', 'isi', '', 'Terbit', 'bukan tanggal'],
        ]));

        $this->assertNotNull(Post::query()->where('title', 'D1')->value('published_at'));
        $this->assertNotNull(Post::query()->where('title', 'D2')->value('published_at'));
    }

    public function test_import_reports_invalid_rows_and_saves_the_valid_ones(): void
    {
        $user = User::factory()->create();

        $result = $this->service->import($user, $this->xlsxUpload([
            ['Judul', 'Kategori', 'Isi', 'Ringkasan', 'Status'],
            ['Valid', 'Umum', 'isi', '', ''],
            ['', 'Umum', 'isi', '', ''],
            ['Judul X', 'Astronomi', 'isi', '', ''],
            ['Judul Y', 'Umum', '', '', ''],
            [null, null, null, null, null],
            ['Judul S', 'Umum', 'isi', '', 'mungkin'],
            ['Judul R', 'Umum', 'isi', str_repeat('r', 1001), ''],
        ]));

        $this->assertSame(1, $result['imported']);
        $this->assertSame([3, 4, 5, 7, 8], array_column($result['errors'], 'row'));
        $this->assertStringContainsString('Judul', $result['errors'][0]['message']);
        $this->assertStringContainsString('Kategori', $result['errors'][1]['message']);
        $this->assertStringContainsString('Isi', $result['errors'][2]['message']);
        $this->assertStringContainsString('Status', $result['errors'][3]['message']);
        $this->assertStringContainsString('Ringkasan', $result['errors'][4]['message']);
        $this->assertSame(1, Post::query()->count());
    }

    public function test_import_with_no_valid_rows_creates_nothing(): void
    {
        $user = User::factory()->create();

        $result = $this->service->import($user, $this->xlsxUpload([
            $this->header(),
            ['', 'Umum', 'isi', '', '', ''],
        ]));

        $this->assertSame(0, $result['imported']);
        $this->assertCount(1, $result['errors']);
        $this->assertSame(0, Post::query()->count());
    }

    public function test_import_rejects_missing_required_columns(): void
    {
        $user = User::factory()->create();

        $one = $this->service->import($user, $this->xlsxUpload([['Judul', 'Isi'], ['A', 'B']]));
        $many = $this->service->import($user, $this->xlsxUpload([['Ringkasan'], ['A']]));

        $this->assertSame(
            ['imported' => 0, 'errors' => [['row' => 1, 'message' => 'Kolom wajib tidak ditemukan: Kategori.']]],
            $one,
        );
        $this->assertSame('Kolom wajib tidak ditemukan: Judul, Kategori, Isi.', $many['errors'][0]['message']);
    }

    public function test_import_rejects_an_unreadable_file(): void
    {
        $user = User::factory()->create();

        $file = new class(__FILE__, 'rusak.xlsx', null, null, true) extends UploadedFile
        {
            public function getRealPath(): string|false
            {
                return '/tidak/ada/rusak.xlsx';
            }
        };

        $result = $this->service->import($user, $file);

        $this->assertSame(0, $result['imported']);
        $this->assertStringContainsString('tidak dapat dibaca', $result['errors'][0]['message']);
    }

    public function test_import_rejects_too_many_rows(): void
    {
        $user = User::factory()->create();
        $rows = [['Judul', 'Kategori', 'Isi'], ...array_fill(0, 501, ['Judul', 'Umum', 'isi'])];

        $result = $this->service->import($user, $this->xlsxUpload($rows));

        $this->assertSame(0, $result['imported']);
        $this->assertStringContainsString('Maksimal 500 baris', $result['errors'][0]['message']);
        $this->assertSame(0, Post::query()->count());
    }

    public function test_import_makes_slugs_unique(): void
    {
        $user = User::factory()->create();
        Post::factory()->create(['slug' => 'sama']);

        $this->service->import($user, $this->xlsxUpload([
            $this->header(),
            ['Sama', 'Umum', 'isi', '', '', ''],
            ['Sama', 'Umum', 'isi', '', '', ''],
        ]));

        $slugs = Post::query()->where('user_id', $user->id)->orderBy('id')->pluck('slug')->all();

        $this->assertSame(['sama-2', 'sama-3'], $slugs);
    }

    public function test_exported_file_can_be_imported_again(): void
    {
        $author = User::factory()->create();
        Post::factory()->create(['user_id' => $author->id]);
        Post::factory()->draft()->create(['user_id' => $author->id]);

        $spreadsheet = $this->service->buildSpreadsheet($this->posts(), false);
        $path = (string) tempnam(sys_get_temp_dir(), 'blogxlsx');
        (new Xlsx($spreadsheet))->save($path);
        $binary = (string) file_get_contents($path);
        unlink($path);

        $other = User::factory()->create();
        $result = $this->service->import($other, UploadedFile::fake()->createWithContent('ekspor.xlsx', $binary));

        $this->assertSame(['imported' => 2, 'errors' => []], $result);
        $this->assertSame(1, $other->posts()->where('is_published', true)->count());
        $this->assertSame(1, $other->posts()->where('is_published', false)->count());
    }
}