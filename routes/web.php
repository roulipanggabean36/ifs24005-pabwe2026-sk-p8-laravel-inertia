<?php

declare(strict_types=1);

use App\Features\Admin\Controllers\AdminUserController;
use App\Features\Auth\Controllers\AuthController;
use App\Features\Post\Controllers\AdminPostController;
use App\Features\Post\Controllers\PostController;
use App\Features\Post\Controllers\PublicPostController;
use App\Features\Profile\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Publik (Guest) - tanpa sidebar
|--------------------------------------------------------------------------
*/
Route::get('/', [PublicPostController::class, 'home'])->name('home');
Route::get('/articles', [PublicPostController::class, 'index'])->name('articles.index');
Route::get('/articles/{slug}', [PublicPostController::class, 'show'])->name('articles.show');

/*
|--------------------------------------------------------------------------
| Autentikasi (Guest)
|--------------------------------------------------------------------------
*/
Route::middleware('guest')->group(function (): void {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login'])->name('login.store');
    Route::get('/register', [AuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [AuthController::class, 'register'])->name('register.store');
});

/*
|--------------------------------------------------------------------------
| Authenticated
|--------------------------------------------------------------------------
*/
Route::middleware('auth')->group(function (): void {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');

    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::put('/profile', [ProfileController::class, 'update'])->name('profile.update');

    // Member (Penulis). Rute statis WAJIB sebelum rute {post}.
    Route::middleware('role:member')
        ->prefix('dashboard/posts')
        ->name('dashboard.posts.')
        ->group(function (): void {
            Route::get('/', [PostController::class, 'index'])->name('index');
            Route::post('/', [PostController::class, 'store'])->name('store');

            Route::get('/export', [PostController::class, 'export'])->name('export');
            Route::post('/import', [PostController::class, 'import'])->name('import');
            Route::post('/ai-generate', [PostController::class, 'aiGenerate'])->name('ai-generate');
            Route::post('/ai-save', [PostController::class, 'aiSave'])->name('ai-save');

            Route::middleware('post.owner')->group(function (): void {
                Route::get('/{post}', [PostController::class, 'show'])->whereNumber('post')->name('show');
                Route::put('/{post}', [PostController::class, 'update'])->whereNumber('post')->name('update');
                Route::delete('/{post}', [PostController::class, 'destroy'])->whereNumber('post')->name('destroy');
                Route::patch('/{post}/publish', [PostController::class, 'publish'])->whereNumber('post')->name('publish');
                Route::post('/{post}/cover', [PostController::class, 'uploadCover'])->whereNumber('post')->name('cover.upload');
                Route::delete('/{post}/cover', [PostController::class, 'removeCover'])->whereNumber('post')->name('cover.remove');
            });
        });

    // Admin
    Route::middleware('role:admin')
        ->prefix('admin')
        ->name('admin.')
        ->group(function (): void {
            Route::get('/users', [AdminUserController::class, 'index'])->name('users.index');
            Route::get('/users/{user}/posts/export', [AdminUserController::class, 'exportPosts'])
                ->whereNumber('user')->name('users.posts.export');
            Route::get('/users/{user}/posts', [AdminUserController::class, 'posts'])
                ->whereNumber('user')->name('users.posts');

            Route::get('/posts/export', [AdminPostController::class, 'export'])->name('posts.export');
            Route::get('/posts', [AdminPostController::class, 'index'])->name('posts.index');
        });
});