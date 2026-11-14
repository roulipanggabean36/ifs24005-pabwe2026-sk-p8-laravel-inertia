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