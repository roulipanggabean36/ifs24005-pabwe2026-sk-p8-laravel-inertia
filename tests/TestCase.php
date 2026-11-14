<?php

declare(strict_types=1);

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Test tidak bergantung pada hasil build Vite (public/build/manifest.json).
        $this->withoutVite();
    }

    /**
     * Pengaman: test tidak boleh berjalan di database aplikasi.
     * Dicek sebelum trait RefreshDatabase sempat menjalankan migrate:fresh.
     */
    protected function refreshApplication(): void
    {
        parent::refreshApplication();

        $default = (string) $this->app['config']->get('database.default');
        $database = (string) $this->app['config']->get("database.connections.{$default}.database");

        $aman = ($default === 'sqlite' && $database === ':memory:') || ($default === 'pgsql' && str_ends_with($database, '_test'));

        if (! $aman) {
            throw new RuntimeException(sprintf(
                'Test harus memakai SQLite in-memory atau PostgreSQL dengan nama database berakhiran "_test" (sekarang: %s / %s). Periksa phpunit.xml.',
                $default,
                $database,
            ));
        }
    }
}