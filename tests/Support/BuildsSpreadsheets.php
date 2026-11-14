<?php

declare(strict_types=1);

namespace Tests\Support;

use Illuminate\Http\UploadedFile;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

trait BuildsSpreadsheets
{
    /**
     * @param  list<list<mixed>>  $rows
     */
    protected function xlsxBinary(array $rows): string
    {
        $spreadsheet = new Spreadsheet();
        $spreadsheet->getActiveSheet()->fromArray($rows, null, 'A1', true);

        $path = (string) tempnam(sys_get_temp_dir(), 'blogxlsx');
        (new Xlsx($spreadsheet))->save($path);

        $binary = (string) file_get_contents($path);
        unlink($path);

        return $binary;
    }

    /**
     * @param  list<list<mixed>>  $rows
     */
    protected function xlsxUpload(array $rows, string $name = 'artikel.xlsx'): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, $this->xlsxBinary($rows));
    }
}