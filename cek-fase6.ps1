$ErrorActionPreference = 'Continue'
$script:ok = 0
$script:bad = 0

function Cek([string]$nama, [bool]$lulus, [string]$info = '') {
    if ($lulus) { Write-Host "OK    $nama" -ForegroundColor Green; $script:ok++ }
    else { Write-Host "GAGAL $nama $info" -ForegroundColor Red; $script:bad++ }
}

if (-not (Test-Path .\artisan)) { Write-Host "Jalankan di root proyek Laravel." -ForegroundColor Red; return }

Write-Host "`n== 0. Repositori Git ==" -ForegroundColor Cyan
$top = (git rev-parse --show-toplevel 2>$null)
$here = (Get-Location).Path -replace '\\', '/'
Cek "Repo git berada di folder proyek" ([bool]$top -and ($top.TrimEnd('/') -ieq $here.TrimEnd('/'))) "(toplevel: $top)"

Write-Host "`n== 1. Struktur Feature-First (soal 3.4) ==" -ForegroundColor Cyan
$berkas = @(
 'app/Features/Admin/Controllers/AdminUserController.php',
 'app/Features/Admin/Services/AdminUserService.php',
 'app/Features/Ai/Contracts/AiClientInterface.php',
 'app/Features/Ai/DTO/GeneratedPostItem.php',
 'app/Features/Ai/Services/OpenAiPostGeneratorService.php',
 'app/Features/Auth/Actions/LoginUserAction.php',
 'app/Features/Auth/Actions/RegisterUserAction.php',
 'app/Features/Auth/Controllers/AuthController.php',
 'app/Features/Post/Contracts/PostRepositoryInterface.php',
 'app/Features/Post/Controllers/AdminPostController.php',
 'app/Features/Post/Controllers/PostController.php',
 'app/Features/Post/Controllers/PublicPostController.php',
 'app/Features/Post/Enums/PostCategory.php',
 'app/Features/Post/Models/Post.php',
 'app/Features/Post/Policies/PostPolicy.php',
 'app/Features/Post/Repositories/PostRepository.php',
 'app/Features/Post/Services/PostExcelService.php',
 'app/Features/Post/Services/PostService.php',
 'app/Features/Profile/Controllers/ProfileController.php',
 'app/Features/Profile/Services/ProfileService.php',
 'app/Http/Middleware/EnsurePostOwnership.php',
 'app/Http/Middleware/EnsureRole.php',
 'app/Http/Middleware/HandleInertiaRequests.php',
 'app/Models/User.php',
 'app/Providers/AppServiceProvider.php',
 'resources/css/app.css',
 'resources/js/app.jsx',
 'resources/js/Layouts/AppLayout.jsx',
 'resources/js/Pages/Admin/PostList.jsx',
 'resources/js/Pages/Admin/UserList.jsx',
 'resources/js/Pages/Admin/UserPostList.jsx',
 'resources/js/Pages/Auth/Login.jsx',
 'resources/js/Pages/Auth/Register.jsx',
 'resources/js/Pages/Post/Index.jsx',
 'resources/js/Pages/Post/Show.jsx',
 'resources/js/Pages/Profile/Edit.jsx',
 'resources/js/Pages/Public/PostIndex.jsx',
 'resources/js/Pages/Public/PostShow.jsx',
 'resources/views/app.blade.php',
 'config/openai.php',
 '.env.example'
)
foreach ($b in $berkas) { Cek $b (Test-Path $b) }

Write-Host "`n== 2. Rute (soal 3.5) ==" -ForegroundColor Cyan
$json = (php artisan route:list --json --except-vendor) -join "`n"
$routes = $json | ConvertFrom-Json
$ada = @{}
foreach ($r in $routes) {
    foreach ($m in ($r.method -split '\|')) {
        $u = ('/' + $r.uri.Trim('/')) -replace '\{[^}]+\}', '{}'
        $ada["$m $u"] = $true
    }
}
$wajib = @(
 'GET /', 'GET /articles', 'GET /articles/{}', 'GET /login', 'GET /register',
 'POST /login', 'POST /register', 'POST /logout',
 'GET /dashboard/posts', 'POST /dashboard/posts', 'GET /dashboard/posts/{}',
 'PUT /dashboard/posts/{}', 'DELETE /dashboard/posts/{}', 'PATCH /dashboard/posts/{}/publish',
 'POST /dashboard/posts/{}/cover', 'DELETE /dashboard/posts/{}/cover',
 'GET /dashboard/posts/export', 'POST /dashboard/posts/import',
 'POST /dashboard/posts/ai-generate', 'POST /dashboard/posts/ai-save',
 'GET /profile',
 'GET /admin/users', 'GET /admin/users/{}/posts', 'GET /admin/users/{}/posts/export',
 'GET /admin/posts', 'GET /admin/posts/export'
)
foreach ($w in $wajib) { Cek "rute $w" ($ada.ContainsKey($w)) }

Write-Host "`n== 3. Kriteria mutu (soal 3.7) ==" -ForegroundColor Cyan
$login = 'resources/js/Pages/Auth/Login.jsx'
foreach ($id in 'login-username', 'login-password', 'login-submit') {
    $hit = (Test-Path $login) -and [bool](Select-String -Path $login -Pattern $id -SimpleMatch -Quiet)
    Cek "Login.jsx memuat $id" $hit
}

$dirs = @('storage/app', 'storage/app/public', 'storage/framework', 'storage/framework/cache', 'storage/framework/cache/data', 'storage/framework/sessions', 'storage/framework/testing', 'storage/framework/views', 'storage/logs')
foreach ($d in $dirs) {
    $gi = "$d/.gitignore"
    $isi = ''
    if (Test-Path $gi) { $isi = Get-Content $gi -Raw }
    $tracked = [bool](git ls-files $gi)
    Cek "$gi ada, berisi * dan !.gitignore, dan dilacak git" ((Test-Path $gi) -and $isi.Contains('*') -and $isi.Contains('!.gitignore') -and $tracked)
}

Cek ".env tidak dilacak git" (-not [bool](git ls-files .env))
$ex = Get-Content .env.example -Raw
Cek ".env.example memakai DB_DATABASE=pabwe_p8_blog" ($ex -match 'DB_DATABASE=pabwe_p8_blog')
Cek ".env.example memakai DB_CONNECTION=pgsql" ($ex -match 'DB_CONNECTION=pgsql')
Cek "config/app.php memuat force_https" ([bool](Select-String -Path config/app.php -Pattern 'force_https' -SimpleMatch -Quiet))

$pkg = Get-Content package.json -Raw
foreach ($p in '@toast-ui/editor', '@inertiajs/react', '@vitejs/plugin-react', 'react-dom') { Cek "package.json memuat $p" ($pkg.Contains($p)) }
$comp = Get-Content composer.json -Raw
foreach ($p in 'inertiajs/inertia-laravel', 'phpoffice/phpspreadsheet') { Cek "composer.json memuat $p" ($comp.Contains($p)) }

Write-Host "`n== 4. Keamanan dan build ==" -ForegroundColor Cyan
composer audit *> $null
Cek "composer audit bersih (0 vulnerability)" ($LASTEXITCODE -eq 0)
composer validate --no-check-publish *> $null
Cek "composer validate" ($LASTEXITCODE -eq 0)
npm run build *> $null
Cek "npm run build sukses" ($LASTEXITCODE -eq 0)

Write-Host "`n== 5. Pengujian (100% coverage) ==" -ForegroundColor Cyan
php artisan test --coverage --min=100 *> $null
Cek "php artisan test --coverage --min=100" ($LASTEXITCODE -eq 0)

Write-Host "`n== 6. Info untuk melengkapi README ==" -ForegroundColor Cyan
Select-String -Path .env.example -Pattern 'OPENAI|AI_|HTTPS|APP_URL' | ForEach-Object { $_.Line }
if (Test-Path database/seeders/DatabaseSeeder.php) {
    Select-String -Path database/seeders/DatabaseSeeder.php -Pattern "username|'role'|password" | ForEach-Object { $_.Line.Trim() }
}

$warna = 'Yellow'
if ($script:bad -eq 0) { $warna = 'Green' }
Write-Host "`nRINGKASAN: $script:ok OK, $script:bad GAGAL" -ForegroundColor $warna
Write-Host "FASE 6 CEK SELESAI." -ForegroundColor Green