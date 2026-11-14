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