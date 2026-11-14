# fase-4d.ps1 - jalankan dari root proyek
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
foreach ($need in @(
  'resources/js/Layouts/AppLayout.jsx',
  'resources/js/Components/Pagination.jsx',
  'resources/js/Components/Ui.jsx',
  'resources/js/Pages/Post/Index.jsx',
  'resources/js/Pages/Post/Show.jsx'
)) {
  if (-not (Test-Path $need)) {
    Write-Host "GAGAL: $need belum ada. Jalankan fase-4a, 4b, dan 4c dulu." -ForegroundColor Red
    exit 1
  }
}

# ---------------------------------------------------------------
# 1. vite.config.js (naikkan batas peringatan ukuran chunk)
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
    build: {
        // TOAST UI Editor berukuran besar dan dimuat terpisah (hanya di modal form).
        chunkSizeWarningLimit: 1000,
    },
    server: {
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
'@

# ---------------------------------------------------------------
# 2. Components bersama untuk halaman Admin
# ---------------------------------------------------------------
W 'resources/js/Components/PostFilterBar.jsx' @'
import { Link, router } from '@inertiajs/react';
import { Search } from 'lucide-react';
import { useEffect, useState } from 'react';
import Button from './Button';
import { inputClass } from './Field';

/**
 * Bilah pencarian + filter kategori + filter status untuk daftar artikel (read-only).
 */
export default function PostFilterBar({ url, filters, categories, total }) {
    const [search, setSearch] = useState(filters.search ?? '');

    useEffect(() => {
        setSearch(filters.search ?? '');
    }, [filters.search]);

    function visit(next) {
        const merged = { ...filters, ...next };
        const query = {};

        ['search', 'category', 'status'].forEach((key) => {
            if (merged[key]) {
                query[key] = merged[key];
            }
        });

        router.get(url, query, { preserveScroll: true, preserveState: true });
    }

    function submit(event) {
        event.preventDefault();
        visit({ search: search.trim() });
    }

    const hasFilter = Boolean(filters.search || filters.category || filters.status);

    return (
        <div>
            <form onSubmit={submit} role="search" className="flex flex-col gap-3 lg:flex-row">
                <div className="relative flex-1">
                    <label htmlFor="admin-filter-search" className="sr-only">
                        Cari artikel berdasarkan judul atau isi
                    </label>
                    <Search
                        className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                        aria-hidden="true"
                    />
                    <input
                        id="admin-filter-search"
                        type="search"
                        value={search}
                        onChange={(event) => setSearch(event.target.value)}
                        placeholder="Cari judul atau isi artikel..."
                        className={`${inputClass(false)} pl-9`}
                    />
                </div>

                <div>
                    <label htmlFor="admin-filter-category" className="sr-only">
                        Filter kategori
                    </label>
                    <select
                        id="admin-filter-category"
                        value={filters.category ?? ''}
                        onChange={(event) => visit({ category: event.target.value })}
                        className={inputClass(false)}
                    >
                        <option value="">Semua kategori</option>
                        {categories.map((category) => (
                            <option key={category.value} value={category.value}>
                                {category.label}
                            </option>
                        ))}
                    </select>
                </div>

                <div>
                    <label htmlFor="admin-filter-status" className="sr-only">
                        Filter status
                    </label>
                    <select
                        id="admin-filter-status"
                        value={filters.status ?? ''}
                        onChange={(event) => visit({ status: event.target.value })}
                        className={inputClass(false)}
                    >
                        <option value="">Semua status</option>
                        <option value="published">Terbit</option>
                        <option value="draft">Draf</option>
                    </select>
                </div>

                <Button type="submit" icon={Search}>
                    Cari
                </Button>
            </form>

            <p className="mt-4 text-sm text-slate-600" aria-live="polite">
                {total} artikel ditemukan
                {hasFilter && (
                    <>
                        {' '}
                        &middot;{' '}
                        <Link href={url} className="font-medium text-indigo-700 hover:underline">
                            Hapus filter
                        </Link>
                    </>
                )}
            </p>
        </div>
    );
}
'@

W 'resources/js/Components/ReadonlyPostList.jsx' @'
import { ExternalLink, FileText } from 'lucide-react';
import { formatDate } from '../lib/format';
import Pagination from './Pagination';
import { CategoryBadge, StatusBadge } from './Ui';

/**
 * Daftar artikel read-only (List view) untuk monitoring admin.
 */
export default function ReadonlyPostList({ posts, showAuthor = false }) {
    if (posts.data.length === 0) {
        return (
            <div className="mt-4 rounded-xl border border-dashed border-slate-300 bg-white p-12 text-center">
                <FileText className="mx-auto h-10 w-10 text-slate-400" aria-hidden="true" />
                <p className="mt-3 font-medium text-slate-900">Tidak ada artikel</p>
                <p className="mt-1 text-sm text-slate-600">
                    Belum ada artikel yang cocok dengan pencarian atau filter ini.
                </p>
            </div>
        );
    }

    return (
        <>
            <div className="mt-4 rounded-xl border border-slate-200 bg-white shadow-xs">
                <ul className="divide-y divide-slate-100">
                    {posts.data.map((post) => (
                        <li
                            key={post.id}
                            className="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center sm:gap-4"
                        >
                            <div className="flex min-w-0 flex-1 items-center gap-4">
                                {post.cover_url ? (
                                    <img
                                        src={post.cover_url}
                                        alt=""
                                        loading="lazy"
                                        className="hidden h-12 w-20 shrink-0 rounded-md object-cover sm:block"
                                    />
                                ) : (
                                    <span
                                        aria-hidden="true"
                                        className="hidden h-12 w-20 shrink-0 items-center justify-center rounded-md bg-slate-100 text-slate-400 sm:flex"
                                    >
                                        <FileText className="h-5 w-5" />
                                    </span>
                                )}

                                <div className="min-w-0">
                                    <p className="truncate font-medium text-slate-900">{post.title}</p>
                                    <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-slate-500">
                                        <CategoryBadge category={post.category} />
                                        <StatusBadge published={post.is_published} />
                                        {showAuthor && (
                                            <span>
                                                oleh {post.author} (@{post.author_username})
                                            </span>
                                        )}
                                        <span>
                                            {post.is_published
                                                ? `Terbit ${formatDate(post.published_at)}`
                                                : `Dibuat ${formatDate(post.created_at)}`}
                                        </span>
                                    </div>
                                </div>
                            </div>

                            {post.is_published && (
                                <a
                                    href={`/articles/${post.slug}`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="inline-flex items-center gap-1.5 self-end rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 sm:self-auto"
                                >
                                    <ExternalLink className="h-4 w-4" aria-hidden="true" />
                                    Lihat
                                    <span className="sr-only"> artikel {post.title} di halaman publik</span>
                                </a>
                            )}
                        </li>
                    ))}
                </ul>
            </div>

            <Pagination paginator={posts} />
        </>
    );
}
'@

# ---------------------------------------------------------------
# 3. Pages/Admin/UserList
# ---------------------------------------------------------------
W 'resources/js/Pages/Admin/UserList.jsx' @'
import { Head, Link, router } from '@inertiajs/react';
import { Download, FileText, Search, Users } from 'lucide-react';
import { useEffect, useState } from 'react';
import Button, { buttonClasses } from '../../Components/Button';
import { inputClass } from '../../Components/Field';
import Pagination from '../../Components/Pagination';
import { PageHeader } from '../../Components/Ui';
import { formatDate, initials } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

function Avatar({ user }) {
    if (user.photo_url) {
        return <img src={user.photo_url} alt="" className="h-9 w-9 rounded-full object-cover" />;
    }

    return (
        <span
            aria-hidden="true"
            className="flex h-9 w-9 items-center justify-center rounded-full bg-indigo-600 text-xs font-semibold text-white"
        >
            {initials(user.name)}
        </span>
    );
}

function RoleBadge({ role }) {
    const admin = role === 'admin';

    return (
        <span
            className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                admin ? 'bg-violet-100 text-violet-800' : 'bg-sky-100 text-sky-800'
            }`}
        >
            {admin ? 'Admin' : 'Penulis'}
        </span>
    );
}

export default function UserList({ users, filters }) {
    const [search, setSearch] = useState(filters.search ?? '');

    useEffect(() => {
        setSearch(filters.search ?? '');
    }, [filters.search]);

    function submit(event) {
        event.preventDefault();

        const term = search.trim();

        router.get('/admin/users', term ? { search: term } : {}, {
            preserveScroll: true,
            preserveState: true,
        });
    }

    return (
        <>
            <Head title="Pengguna" />

            <PageHeader
                title="Pengguna"
                description="Daftar seluruh pengguna beserta jumlah artikelnya. Pilih pengguna untuk memantau artikelnya."
                actions={
                    <>
                        <Link href="/admin/posts" className={buttonClasses('secondary', 'md')}>
                            <FileText className="h-4 w-4" aria-hidden="true" />
                            Semua Artikel
                        </Link>
                        <a
                            id="btn-export-all-posts"
                            href="/admin/posts/export"
                            className={buttonClasses('primary', 'md')}
                        >
                            <Download className="h-4 w-4" aria-hidden="true" />
                            Ekspor Semua Artikel
                        </a>
                    </>
                }
            />

            <form onSubmit={submit} role="search" className="flex flex-col gap-3 sm:flex-row">
                <div className="relative flex-1">
                    <label htmlFor="user-search" className="sr-only">
                        Cari pengguna berdasarkan nama atau username
                    </label>
                    <Search
                        className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                        aria-hidden="true"
                    />
                    <input
                        id="user-search"
                        type="search"
                        value={search}
                        onChange={(event) => setSearch(event.target.value)}
                        placeholder="Cari nama atau username..."
                        className={`${inputClass(false)} pl-9`}
                    />
                </div>
                <Button type="submit" icon={Search}>
                    Cari
                </Button>
            </form>

            <p className="mt-4 text-sm text-slate-600" aria-live="polite">
                {users.total} pengguna ditemukan
                {filters.search && (
                    <>
                        {' '}
                        &middot;{' '}
                        <Link href="/admin/users" className="font-medium text-indigo-700 hover:underline">
                            Hapus pencarian
                        </Link>
                    </>
                )}
            </p>

            {users.data.length === 0 ? (
                <div className="mt-4 rounded-xl border border-dashed border-slate-300 bg-white p-12 text-center">
                    <Users className="mx-auto h-10 w-10 text-slate-400" aria-hidden="true" />
                    <p className="mt-3 font-medium text-slate-900">Pengguna tidak ditemukan</p>
                </div>
            ) : (
                <div className="mt-4 overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-xs">
                    <table className="min-w-full divide-y divide-slate-200 text-sm">
                        <caption className="sr-only">Daftar pengguna</caption>
                        <thead className="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                            <tr>
                                <th scope="col" className="px-4 py-3">Pengguna</th>
                                <th scope="col" className="px-4 py-3">Peran</th>
                                <th scope="col" className="px-4 py-3 text-right">Artikel</th>
                                <th scope="col" className="px-4 py-3">Bergabung</th>
                                <th scope="col" className="px-4 py-3 text-right">Aksi</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {users.data.map((user) => (
                                <tr key={user.id}>
                                    <td className="px-4 py-3">
                                        <div className="flex items-center gap-3">
                                            <Avatar user={user} />
                                            <div className="min-w-0">
                                                <p className="truncate font-medium text-slate-900">
                                                    {user.name}
                                                </p>
                                                <p className="truncate text-xs text-slate-500">
                                                    @{user.username}
                                                </p>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="px-4 py-3">
                                        <RoleBadge role={user.role} />
                                    </td>
                                    <td className="px-4 py-3 text-right font-medium text-slate-900">
                                        {user.posts_count}
                                    </td>
                                    <td className="whitespace-nowrap px-4 py-3 text-slate-600">
                                        {formatDate(user.created_at)}
                                    </td>
                                    <td className="px-4 py-3">
                                        <div className="flex justify-end gap-2">
                                            <Link
                                                href={`/admin/users/${user.id}/posts`}
                                                className={buttonClasses('secondary', 'sm')}
                                            >
                                                <FileText className="h-4 w-4" aria-hidden="true" />
                                                Lihat artikel
                                                <span className="sr-only"> milik {user.name}</span>
                                            </Link>
                                            <a
                                                href={`/admin/users/${user.id}/posts/export`}
                                                className={buttonClasses('ghost', 'sm')}
                                            >
                                                <Download className="h-4 w-4" aria-hidden="true" />
                                                Ekspor
                                                <span className="sr-only"> artikel milik {user.name}</span>
                                            </a>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            <Pagination paginator={users} />
        </>
    );
}

UserList.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 4. Pages/Admin/PostList
# ---------------------------------------------------------------
W 'resources/js/Pages/Admin/PostList.jsx' @'
import { Head, Link } from '@inertiajs/react';
import { ArrowLeft, Download } from 'lucide-react';
import { buttonClasses } from '../../Components/Button';
import PostFilterBar from '../../Components/PostFilterBar';
import ReadonlyPostList from '../../Components/ReadonlyPostList';
import { PageHeader } from '../../Components/Ui';
import AppLayout from '../../Layouts/AppLayout';

export default function PostList({ posts, filters, categories }) {
    return (
        <>
            <Head title="Semua Artikel" />

            <PageHeader
                title="Semua Artikel"
                description="Pantau artikel seluruh pengguna (hanya-baca)."
                actions={
                    <>
                        <Link href="/admin/users" className={buttonClasses('secondary', 'md')}>
                            <ArrowLeft className="h-4 w-4" aria-hidden="true" />
                            Pengguna
                        </Link>
                        <a
                            id="btn-export-all-posts"
                            href="/admin/posts/export"
                            className={buttonClasses('primary', 'md')}
                        >
                            <Download className="h-4 w-4" aria-hidden="true" />
                            Ekspor Semua Artikel
                        </a>
                    </>
                }
            />

            <PostFilterBar
                url="/admin/posts"
                filters={filters}
                categories={categories}
                total={posts.total}
            />

            <ReadonlyPostList posts={posts} showAuthor />
        </>
    );
}

PostList.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 5. Pages/Admin/UserPostList
# ---------------------------------------------------------------
W 'resources/js/Pages/Admin/UserPostList.jsx' @'
import { Head, Link } from '@inertiajs/react';
import { ArrowLeft, CircleCheck, Clock, Download, FileText } from 'lucide-react';
import { buttonClasses } from '../../Components/Button';
import PostFilterBar from '../../Components/PostFilterBar';
import ReadonlyPostList from '../../Components/ReadonlyPostList';
import { PageHeader, StatCard } from '../../Components/Ui';
import AppLayout from '../../Layouts/AppLayout';

export default function UserPostList({ owner, posts, stats, filters, categories }) {
    return (
        <>
            <Head title={`Artikel ${owner.name}`} />

            <PageHeader
                title={`Artikel ${owner.name}`}
                description={`@${owner.username} - monitoring artikel (hanya-baca).`}
                actions={
                    <>
                        <Link href="/admin/users" className={buttonClasses('secondary', 'md')}>
                            <ArrowLeft className="h-4 w-4" aria-hidden="true" />
                            Kembali ke pengguna
                        </Link>
                        <a
                            id="btn-export-user-posts"
                            href={`/admin/users/${owner.id}/posts/export`}
                            className={buttonClasses('primary', 'md')}
                        >
                            <Download className="h-4 w-4" aria-hidden="true" />
                            Ekspor Artikel Pengguna
                        </a>
                    </>
                }
            />

            <section aria-label="Ringkasan statistik artikel" className="mb-6 grid gap-4 sm:grid-cols-3">
                <StatCard label="Total Artikel" value={stats.total} icon={FileText} tone="indigo" />
                <StatCard label="Total Selesai" value={stats.published} icon={CircleCheck} tone="emerald" />
                <StatCard label="Belum Selesai" value={stats.draft} icon={Clock} tone="amber" />
            </section>

            <PostFilterBar
                url={`/admin/users/${owner.id}/posts`}
                filters={filters}
                categories={categories}
                total={posts.total}
            />

            <ReadonlyPostList posts={posts} />
        </>
    );
}

UserPostList.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 6. Cek struktur Pages sesuai 3.4
# ---------------------------------------------------------------
$expectedPages = @(
  'Admin/PostList', 'Admin/UserList', 'Admin/UserPostList',
  'Auth/Login', 'Auth/Register',
  'Post/Index', 'Post/Show',
  'Profile/Edit',
  'Public/PostIndex', 'Public/PostShow'
)
$missingPages = @($expectedPages | Where-Object { -not (Test-Path "resources/js/Pages/$_.jsx") })
if ($missingPages.Count -gt 0) {
  Write-Host "GAGAL: halaman berikut belum ada: $($missingPages -join ', ')" -ForegroundColor Red
  exit 1
}
Write-Host ("Struktur Pages sesuai 3.4: {0} dari {0} halaman ada." -f $expectedPages.Count) -ForegroundColor Green

# ---------------------------------------------------------------
# 7. Cek bundle (sintaks + import)
# ---------------------------------------------------------------
$root = (Get-Location).Path
$entries = Get-ChildItem resources/js -Recurse -File -Include *.jsx,*.js |
  Where-Object { $_.Name -ne 'app.jsx' }
$lines = foreach ($e in $entries) {
  $rel = $e.FullName.Substring($root.Length + 1).Replace('\', '/')
  "import './$rel';"
}
W 'tmp-check.jsx' ($lines -join "`n")

$out = Join-Path $env:TEMP 'esbuild-check.js'
$esArgs = @('tmp-check.jsx', '--bundle', "--outfile=$out", '--jsx=automatic',
            '--loader:.css=empty', '--platform=browser', '--log-level=error')
$esLocal = Join-Path $root 'node_modules\.bin\esbuild.cmd'
if (Test-Path $esLocal) { & $esLocal @esArgs } else { npx --yes esbuild @esArgs }
$esExit = $LASTEXITCODE
Remove-Item tmp-check.jsx -Force
if (Test-Path $out) { Remove-Item $out -Force }

if ($esExit -ne 0) {
  Write-Host "GAGAL: ada kesalahan sintaks atau import di file JSX (lihat pesan di atas)." -ForegroundColor Red
  exit 1
}
Write-Host "Cek bundle: sintaks dan semua import valid ($($entries.Count) file)." -ForegroundColor Green

# ---------------------------------------------------------------
# 8. Build Vite penuh
# ---------------------------------------------------------------
Write-Host ">> npm run build" -ForegroundColor Cyan
npm run build
if ($LASTEXITCODE -ne 0) {
  Write-Host "GAGAL: npm run build (exit code $LASTEXITCODE)" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "FASE 4d SELESAI." -ForegroundColor Green