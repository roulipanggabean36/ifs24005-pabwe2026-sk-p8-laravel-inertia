# fase-1.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

function Run([string]$label, [scriptblock]$cmd) {
  Write-Host ">> $label" -ForegroundColor Cyan
  & $cmd
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: $label (exit code $LASTEXITCODE)" -ForegroundColor Red
    exit 1
  }
}

if (-not (Test-Path .\artisan) -or -not (Test-Path .\composer.json) -or -not (Test-Path .\package.json)) {
  Write-Host "GAGAL: jalankan dari root proyek Laravel (artisan, composer.json, package.json harus ada)." -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------
# 1. .npmrc (sebelum npm install)
# ---------------------------------------------------------------
W '.npmrc' @'
legacy-peer-deps=true
fund=false
'@

# ---------------------------------------------------------------
# 2. Dependensi Composer
#    Catatan: pakai ~2.0 (bukan ^2.0) karena ^ adalah karakter escape di cmd/composer.bat Windows.
# ---------------------------------------------------------------
Run 'composer require inertia + phpspreadsheet' {
  composer require inertiajs/inertia-laravel:~2.0 phpoffice/phpspreadsheet --no-interaction
}

# Tambah script test & test:coverage ke composer.json secara terstruktur
W 'tmp-patch-composer.php' @'
<?php
$file = __DIR__ . '/composer.json';
$data = json_decode(file_get_contents($file), false, 512, JSON_THROW_ON_ERROR);
if (!isset($data->scripts)) {
    $data->scripts = new stdClass();
}
$data->scripts->{'test'} = [
    '@php artisan config:clear --ansi',
    '@php artisan test',
];
$data->scripts->{'test:coverage'} = [
    '@putenv XDEBUG_MODE=coverage',
    '@php artisan config:clear --ansi',
    '@php artisan test --coverage --min=100',
];
file_put_contents(
    $file,
    json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n"
);
echo "composer.json scripts updated\n";
'@
Run 'patch composer.json (script test)' { php tmp-patch-composer.php }
Remove-Item tmp-patch-composer.php -Force

# ---------------------------------------------------------------
# 3. Dependensi NPM
# ---------------------------------------------------------------
Run 'npm install (dependensi bawaan)' { npm install }
Run 'npm install paket runtime' {
  npm install @inertiajs/react@2 react react-dom @toast-ui/editor lucide-react dompurify
}
Run 'npm install plugin-react' { npm install -D @vitejs/plugin-react }

if (-not (Test-Path 'node_modules\@tailwindcss\vite')) {
  Run 'npm install tailwind (tidak ada di bawaan)' { npm install -D tailwindcss @tailwindcss/vite }
}
if (-not (Test-Path 'node_modules\laravel-vite-plugin')) {
  Run 'npm install laravel-vite-plugin' { npm install -D laravel-vite-plugin }
}

# ---------------------------------------------------------------
# 4. Konfigurasi
# ---------------------------------------------------------------
W 'vite.config.js' @'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.jsx'],
            refresh: true,
        }),
        react(),
        tailwindcss(),
    ],
    server: {
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
'@

W 'config/app.php' @'
<?php

declare(strict_types=1);

return [

    'name' => env('APP_NAME', 'BlogVerse Pro'),

    'env' => env('APP_ENV', 'production'),

    'debug' => (bool) env('APP_DEBUG', false),

    'url' => env('APP_URL', 'http://localhost'),

    'force_https' => (bool) env('APP_FORCE_HTTPS', false),

    'timezone' => 'Asia/Jakarta',

    'locale' => env('APP_LOCALE', 'id'),

    'fallback_locale' => env('APP_FALLBACK_LOCALE', 'en'),

    'faker_locale' => env('APP_FAKER_LOCALE', 'id_ID'),

    'cipher' => 'AES-256-CBC',

    'key' => env('APP_KEY'),

    'previous_keys' => array_filter(
        explode(',', (string) env('APP_PREVIOUS_KEYS', ''))
    ),

    'maintenance' => [
        'driver' => env('APP_MAINTENANCE_DRIVER', 'file'),
        'store' => env('APP_MAINTENANCE_STORE', 'database'),
    ],

];
'@

W 'config/openai.php' @'
<?php

declare(strict_types=1);

return [

    'api_key' => env('OPENAI_API_KEY'),

    'model' => env('OPENAI_MODEL', 'gpt-4o-mini'),

    'base_url' => env('OPENAI_BASE_URL', 'https://api.openai.com/v1'),

    'timeout' => (int) env('OPENAI_TIMEOUT', 60),

];
'@

W '.gitignore' @'
*.log
.DS_Store
.env
.env.backup
.env.production
.phpactor.json
.phpunit.cache
.phpunit.result.cache
/.fleet
/.idea
/.nova
/.vscode
/.zed
/auth.json
/node_modules
/public/build
/public/hot
/public/storage
/storage/*.key
/storage/pail
/vendor
Homestead.json
Homestead.yaml
Thumbs.db

# Hasil uji / CI
coverage-*
coverage.txt
coverage.xml
junit.xml
events.txt
phpunit_*.txt
trivy
latest-app.zip
'@

# ---------------------------------------------------------------
# 5. .env.example dan .env
# ---------------------------------------------------------------
$envTemplate = @'
APP_NAME="BlogVerse Pro"
APP_ENV=local
APP_KEY=__APP_KEY__
APP_DEBUG=true
APP_URL=http://localhost:8000
APP_FORCE_HTTPS=false

APP_LOCALE=id
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=id_ID

APP_MAINTENANCE_DRIVER=file

PHP_CLI_SERVER_WORKERS=4

BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=pabwe_p8_blog
DB_USERNAME=postgres
DB_PASSWORD=__DB_PASSWORD__

SESSION_DRIVER=file
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync

CACHE_STORE=file

MAIL_MAILER=log
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"

OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_TIMEOUT=60

VITE_APP_NAME="${APP_NAME}"
'@

W '.env.example' ($envTemplate.Replace('__APP_KEY__', '').Replace('__DB_PASSWORD__', 'postgres'))

# Pertahankan APP_KEY yang sudah ada
$appKey = ''
if (Test-Path .env) {
  $m = Select-String -Path .env -Pattern '^APP_KEY=(.*)$'
  if ($m) { $appKey = $m.Matches[0].Groups[1].Value.Trim() }
}

$sec = Read-Host 'Password PostgreSQL user postgres (Enter = postgres)' -AsSecureString
$dbPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if ([string]::IsNullOrEmpty($dbPass)) { $dbPass = 'postgres' }
if ($dbPass -match '^[A-Za-z0-9_.\-]+$') { $dbEnv = $dbPass }
else { $dbEnv = "'" + $dbPass.Replace("'", "\'") + "'" }

W '.env' ($envTemplate.Replace('__APP_KEY__', $appKey).Replace('__DB_PASSWORD__', $dbEnv))

if ([string]::IsNullOrEmpty($appKey)) {
  Run 'key:generate' { php artisan key:generate --force }
}

# ---------------------------------------------------------------
# 6. Frontend: view, CSS, JS, favicon
# ---------------------------------------------------------------
W 'resources/views/app.blade.php' @'
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title inertia>{{ config('app.name', 'BlogVerse Pro') }}</title>
    <link rel="icon" type="image/svg+xml" href="/favicon.svg">
    @viteReactRefresh
    @vite(['resources/css/app.css', 'resources/js/app.jsx'])
    @inertiaHead
</head>
<body class="antialiased">
    @inertia
</body>
</html>
'@

W 'resources/css/app.css' @'
@import 'tailwindcss';

@source '../../vendor/laravel/framework/src/Illuminate/Pagination/resources/views/*.blade.php';
@source '../../storage/framework/views/*.php';
@source '../**/*.blade.php';
@source '../**/*.jsx';

@theme {
    --font-sans: ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto,
        'Helvetica Neue', Arial, 'Noto Sans', sans-serif;
    --font-serif: ui-serif, Georgia, Cambria, 'Times New Roman', Times, serif;
}

@layer base {
    /* Tailwind v4 memakai cursor default pada tombol; kembalikan pointer. */
    button:not(:disabled),
    [role='button']:not([aria-disabled='true']),
    a[href],
    summary,
    select,
    label[for],
    input[type='checkbox'],
    input[type='radio'],
    input[type='file'],
    input[type='submit'] {
        cursor: pointer;
    }

    button:disabled,
    [aria-disabled='true'] {
        cursor: not-allowed;
    }
}
'@

W 'resources/js/app.jsx' @'
import { createInertiaApp } from '@inertiajs/react';
import { resolvePageComponent } from 'laravel-vite-plugin/inertia-helpers';
import { createRoot } from 'react-dom/client';

const appName = import.meta.env.VITE_APP_NAME || 'BlogVerse Pro';

createInertiaApp({
    title: (title) => (title ? `${title} - ${appName}` : appName),
    resolve: (name) =>
        resolvePageComponent(`./Pages/${name}.jsx`, import.meta.glob('./Pages/**/*.jsx')),
    progress: false,
    setup({ el, App, props }) {
        createRoot(el).render(<App {...props} />);
    },
});
'@

# Hapus file JS bawaan skeleton yang tidak dipakai (struktur 3.4 hanya app.jsx)
foreach ($old in @('resources/js/app.js', 'resources/js/bootstrap.js')) {
  if (Test-Path $old) { Remove-Item $old -Force; Write-Host "DEL $old" }
}

W 'public/favicon.svg' @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="14" fill="#4f46e5"/>
  <path d="M20 16h14a10 10 0 0 1 4 19 10 10 0 0 1-4 13H20z" fill="#fff"/>
  <path d="M28 24v6h5a3 3 0 0 0 0-6zm0 14v6h6a3 3 0 0 0 0-6z" fill="#4f46e5"/>
</svg>
'@

W 'test.bat' @'
@echo off
setlocal
set XDEBUG_MODE=coverage
call php artisan config:clear
call php artisan test --coverage --min=100
exit /b %ERRORLEVEL%
'@

# ---------------------------------------------------------------
# 7. .gitignore untuk seluruh subdirektori storage
# ---------------------------------------------------------------
$storageIgnores = @(
  @{ Dir = 'storage/app';                  Body = "*`n!public/`n!.gitignore`n" },
  @{ Dir = 'storage/app/public';           Body = "*`n!.gitignore`n" },
  @{ Dir = 'storage/framework';            Body = "*`n!cache/`n!sessions/`n!testing/`n!views/`n!.gitignore`n" },
  @{ Dir = 'storage/framework/cache';      Body = "*`n!data/`n!.gitignore`n" },
  @{ Dir = 'storage/framework/cache/data'; Body = "*`n!.gitignore`n" },
  @{ Dir = 'storage/framework/sessions';   Body = "*`n!.gitignore`n" },
  @{ Dir = 'storage/framework/testing';    Body = "*`n!.gitignore`n" },
  @{ Dir = 'storage/framework/views';      Body = "*`n!.gitignore`n" },
  @{ Dir = 'storage/logs';                 Body = "*`n!.gitignore`n" }
)
foreach ($item in $storageIgnores) {
  W "$($item.Dir)/.gitignore" $item.Body
}

# ---------------------------------------------------------------
# 8. Penutup setup
# ---------------------------------------------------------------
Run 'config:clear' { php artisan config:clear }

if (Test-Path 'public\storage') { cmd /c rmdir public\storage }
Run 'storage:link' { php artisan storage:link }

Run 'npm run build' { npm run build }

Run 'about' { php artisan about }

Write-Host ""
Write-Host "FASE 1 SELESAI." -ForegroundColor Green