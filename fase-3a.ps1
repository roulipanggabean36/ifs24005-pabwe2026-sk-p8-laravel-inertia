# fase-3a.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path .\artisan)) {
  Write-Host "GAGAL: jalankan dari root proyek Laravel." -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------
# 1. bootstrap/app.php
# ---------------------------------------------------------------
W 'bootstrap/app.php' @'
<?php

declare(strict_types=1);

use App\Http\Middleware\EnsurePostOwnership;
use App\Http\Middleware\EnsureRole;
use App\Http\Middleware\HandleInertiaRequests;
use App\Models\User;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->web(append: [
            HandleInertiaRequests::class,
        ]);

        $middleware->alias([
            'role' => EnsureRole::class,
            'post.owner' => EnsurePostOwnership::class,
        ]);

        $middleware->redirectGuestsTo(fn (Request $request): string => route('login'));

        $middleware->redirectUsersTo(
            fn (Request $request): string => $request->user()?->role === User::ROLE_ADMIN
                ? route('admin.users.index')
                : route('dashboard.posts.index')
        );
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
'@

# ---------------------------------------------------------------
# 2. Middleware
# ---------------------------------------------------------------
W 'app/Http/Middleware/HandleInertiaRequests.php' @'
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Illuminate\Http\Request;
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    /**
     * @var string
     */
    protected $rootView = 'app';

    /**
     * @return array<string, mixed>
     */
    public function share(Request $request): array
    {
        $user = $request->user();

        return [
            ...parent::share($request),
            'appName' => config('app.name'),
            'auth' => [
                'user' => $user === null ? null : [
                    'id' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'role' => $user->role,
                    'is_admin' => $user->isAdmin(),
                    'photo_url' => $user->profilePhotoUrl(),
                ],
            ],
            'flash' => [
                'success' => fn (): mixed => $request->session()->get('success'),
                'error' => fn (): mixed => $request->session()->get('error'),
                'import_errors' => fn (): mixed => $request->session()->get('import_errors', []),
            ],
        ];
    }
}
'@

W 'app/Http/Middleware/EnsureRole.php' @'
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if ($user === null || ! in_array($user->role, $roles, true)) {
            abort(Response::HTTP_FORBIDDEN, 'Anda tidak memiliki akses ke halaman ini.');
        }

        return $next($request);
    }
}
'@

W 'app/Http/Middleware/EnsurePostOwnership.php' @'
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Features\Post\Models\Post;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePostOwnership
{
    public function handle(Request $request, Closure $next): Response
    {
        $post = $request->route('post');

        if (! $post instanceof Post || $post->user_id !== $request->user()?->id) {
            abort(Response::HTTP_FORBIDDEN, 'Artikel ini bukan milik Anda.');
        }

        return $next($request);
    }
}
'@

# ---------------------------------------------------------------
# 3. Auth
# ---------------------------------------------------------------
W 'app/Features/Auth/Actions/LoginUserAction.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Auth\Actions;

use Illuminate\Support\Facades\Auth;

class LoginUserAction
{
    public function execute(string $username, string $password, bool $remember = false): bool
    {
        return Auth::attempt(
            ['username' => $username, 'password' => $password],
            $remember,
        );
    }
}
'@

W 'app/Features/Auth/Actions/RegisterUserAction.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Auth\Actions;

use App\Models\User;
use Illuminate\Support\Facades\Auth;

class RegisterUserAction
{
    /**
     * @param  array{name: string, username: string, password: string}  $data
     */
    public function execute(array $data): User
    {
        $user = User::query()->create([
            'name' => $data['name'],
            'username' => $data['username'],
            'password' => $data['password'],
            'role' => User::ROLE_MEMBER,
        ]);

        Auth::login($user);

        return $user;
    }
}
'@

W 'app/Features/Auth/Controllers/AuthController.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Auth\Controllers;

use App\Features\Auth\Actions\LoginUserAction;
use App\Features\Auth\Actions\RegisterUserAction;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

class AuthController
{
    public function __construct(
        private readonly LoginUserAction $loginAction,
        private readonly RegisterUserAction $registerAction,
    ) {}

    public function showLogin(): Response
    {
        return Inertia::render('Auth/Login');
    }

    public function showRegister(): Response
    {
        return Inertia::render('Auth/Register');
    }

    public function login(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'username' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);

        $authenticated = $this->loginAction->execute(
            $credentials['username'],
            $credentials['password'],
            $request->boolean('remember'),
        );

        if (! $authenticated) {
            throw ValidationException::withMessages([
                'username' => 'Username atau kata sandi salah.',
            ]);
        }

        $request->session()->regenerate();

        return redirect()->route($this->homeRoute($request->user()));
    }

    public function register(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'username' => ['required', 'string', 'min:3', 'max:50', 'alpha_dash:ascii', 'unique:users,username'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = $this->registerAction->execute($data);

        $request->session()->regenerate();

        return redirect()
            ->route($this->homeRoute($user))
            ->with('success', 'Pendaftaran berhasil. Selamat datang, '.$user->name.'!');
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('home');
    }

    private function homeRoute(User $user): string
    {
        return $user->isAdmin() ? 'admin.users.index' : 'dashboard.posts.index';
    }
}
'@

# ---------------------------------------------------------------
# 4. Profile
# ---------------------------------------------------------------
W 'app/Features/Profile/Services/ProfileService.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Profile\Services;

use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class ProfileService
{
    /**
     * @param  array{name: string, username: string, password?: string|null}  $data
     */
    public function update(
        User $user,
        array $data,
        ?UploadedFile $photo = null,
        bool $removePhoto = false,
    ): User {
        $attributes = [
            'name' => $data['name'],
            'username' => $data['username'],
        ];

        if (! empty($data['password'])) {
            $attributes['password'] = $data['password'];
        }

        if ($photo !== null) {
            $this->deletePhoto($user);
            $attributes['profile_photo_path'] = $photo->store('profile-photos', 'public');
        } elseif ($removePhoto) {
            $this->deletePhoto($user);
            $attributes['profile_photo_path'] = null;
        }

        $user->update($attributes);

        return $user->refresh();
    }

    private function deletePhoto(User $user): void
    {
        if ($user->profile_photo_path !== null) {
            Storage::disk('public')->delete($user->profile_photo_path);
        }
    }
}
'@

W 'app/Features/Profile/Controllers/ProfileController.php' @'
<?php

declare(strict_types=1);

namespace App\Features\Profile\Controllers;

use App\Features\Profile\Services\ProfileService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

class ProfileController
{
    public function __construct(private readonly ProfileService $service) {}

    public function edit(Request $request): Response
    {
        $user = $request->user();

        return Inertia::render('Profile/Edit', [
            'profile' => [
                'name' => $user->name,
                'username' => $user->username,
                'photo_url' => $user->profilePhotoUrl(),
            ],
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'username' => [
                'required', 'string', 'min:3', 'max:50', 'alpha_dash:ascii',
                Rule::unique('users', 'username')->ignore($user->id),
            ],
            'password' => ['nullable', 'string', 'min:8', 'confirmed'],
            'photo' => ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
            'remove_photo' => ['nullable', 'boolean'],
        ]);

        $this->service->update(
            $user,
            $data,
            $request->file('photo'),
            $request->boolean('remove_photo'),
        );

        return redirect()
            ->route('profile.edit')
            ->with('success', 'Profil berhasil diperbarui.');
    }
}
'@

# ---------------------------------------------------------------
# 5. Hapus Controller bawaan (struktur 3.4 tidak memilikinya)
# ---------------------------------------------------------------
if (Test-Path 'app/Http/Controllers/Controller.php') {
  Remove-Item 'app/Http/Controllers/Controller.php' -Force
  Write-Host "DEL app/Http/Controllers/Controller.php"
}
if ((Test-Path 'app/Http/Controllers') -and -not (Get-ChildItem 'app/Http/Controllers')) {
  Remove-Item 'app/Http/Controllers' -Force
  Write-Host "DEL app/Http/Controllers (kosong)"
}

# ---------------------------------------------------------------
# 6. Lint sintaks PHP
# ---------------------------------------------------------------
$phpFiles = @(
  'bootstrap/app.php',
  'app/Http/Middleware/HandleInertiaRequests.php',
  'app/Http/Middleware/EnsureRole.php',
  'app/Http/Middleware/EnsurePostOwnership.php',
  'app/Features/Auth/Actions/LoginUserAction.php',
  'app/Features/Auth/Actions/RegisterUserAction.php',
  'app/Features/Auth/Controllers/AuthController.php',
  'app/Features/Profile/Services/ProfileService.php',
  'app/Features/Profile/Controllers/ProfileController.php'
)
foreach ($f in $phpFiles) {
  php -l $f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: sintaks PHP salah di $f" -ForegroundColor Red
    php -l $f
    exit 1
  }
}
Write-Host "Lint PHP: semua file valid." -ForegroundColor Green

Write-Host ""
Write-Host "FASE 3a SELESAI." -ForegroundColor Green