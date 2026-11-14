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