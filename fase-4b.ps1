# fase-4b.ps1 - jalankan dari root proyek
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
foreach ($need in @('resources/js/Layouts/AppLayout.jsx', 'resources/js/Components/Field.jsx', 'resources/js/Components/MarkdownViewer.jsx', 'resources/js/lib/format.js')) {
  if (-not (Test-Path $need)) {
    Write-Host "GAGAL: $need belum ada. Jalankan fase-4a.ps1 dulu." -ForegroundColor Red
    exit 1
  }
}

# ---------------------------------------------------------------
# 1. Auth/Login
# ---------------------------------------------------------------
W 'resources/js/Pages/Auth/Login.jsx' @'
import { Head, Link, useForm } from '@inertiajs/react';
import { Eye, EyeOff, LogIn } from 'lucide-react';
import { useState } from 'react';
import Button from '../../Components/Button';
import Field, { inputClass } from '../../Components/Field';
import AppLayout from '../../Layouts/AppLayout';

export default function Login() {
    const { data, setData, post, processing, errors, reset } = useForm({
        username: '',
        password: '',
        remember: false,
    });
    const [showPassword, setShowPassword] = useState(false);

    function submit(event) {
        event.preventDefault();
        post('/login', { onFinish: () => reset('password') });
    }

    return (
        <>
            <Head title="Masuk" />

            <div className="mx-auto flex max-w-md flex-col px-4 py-12 sm:py-16">
                <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
                    <h1 className="text-2xl font-bold text-slate-900">Masuk ke BlogVerse Pro</h1>
                    <p className="mt-1 text-sm text-slate-600">
                        Gunakan username dan kata sandi Anda untuk mengelola artikel.
                    </p>

                    <form onSubmit={submit} noValidate className="mt-6 space-y-5">
                        <Field id="login-username" label="Username" error={errors.username}>
                            <input
                                id="login-username"
                                name="username"
                                type="text"
                                autoComplete="username"
                                value={data.username}
                                onChange={(event) => setData('username', event.target.value)}
                                aria-invalid={Boolean(errors.username)}
                                aria-describedby={errors.username ? 'login-username-error' : undefined}
                                className={inputClass(Boolean(errors.username))}
                            />
                        </Field>

                        <Field id="login-password" label="Kata sandi" error={errors.password}>
                            <div className="relative">
                                <input
                                    id="login-password"
                                    name="password"
                                    type={showPassword ? 'text' : 'password'}
                                    autoComplete="current-password"
                                    value={data.password}
                                    onChange={(event) => setData('password', event.target.value)}
                                    aria-invalid={Boolean(errors.password)}
                                    aria-describedby={errors.password ? 'login-password-error' : undefined}
                                    className={`${inputClass(Boolean(errors.password))} pr-10`}
                                />
                                <button
                                    type="button"
                                    onClick={() => setShowPassword((value) => !value)}
                                    aria-label={showPassword ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'}
                                    className="absolute inset-y-0 right-0 flex items-center px-3 text-slate-500 hover:text-slate-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                                >
                                    {showPassword ? (
                                        <EyeOff className="h-4 w-4" aria-hidden="true" />
                                    ) : (
                                        <Eye className="h-4 w-4" aria-hidden="true" />
                                    )}
                                </button>
                            </div>
                        </Field>

                        <label className="flex items-center gap-2 text-sm text-slate-700">
                            <input
                                id="login-remember"
                                type="checkbox"
                                checked={data.remember}
                                onChange={(event) => setData('remember', event.target.checked)}
                                className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                            />
                            Ingat saya
                        </label>

                        <Button
                            id="login-submit"
                            type="submit"
                            loading={processing}
                            icon={LogIn}
                            className="w-full"
                        >
                            Masuk
                        </Button>
                    </form>

                    <p className="mt-6 text-center text-sm text-slate-600">
                        Belum punya akun?{' '}
                        <Link href="/register" className="font-medium text-indigo-700 hover:underline">
                            Daftar sebagai penulis
                        </Link>
                    </p>
                </div>
            </div>
        </>
    );
}

Login.layout = (page) => <AppLayout variant="public">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 2. Auth/Register
# ---------------------------------------------------------------
W 'resources/js/Pages/Auth/Register.jsx' @'
import { Head, Link, useForm } from '@inertiajs/react';
import { UserPlus } from 'lucide-react';
import Button from '../../Components/Button';
import Field, { inputClass } from '../../Components/Field';
import AppLayout from '../../Layouts/AppLayout';

export default function Register() {
    const { data, setData, post, processing, errors, reset } = useForm({
        name: '',
        username: '',
        password: '',
        password_confirmation: '',
    });

    function submit(event) {
        event.preventDefault();
        post('/register', {
            onFinish: () => reset('password', 'password_confirmation'),
        });
    }

    const bind = (field, autoComplete) => ({
        id: `register-${field.replace('_', '-')}`,
        name: field,
        autoComplete,
        value: data[field],
        onChange: (event) => setData(field, event.target.value),
        'aria-invalid': Boolean(errors[field]),
        'aria-describedby': errors[field] ? `register-${field.replace('_', '-')}-error` : undefined,
        className: inputClass(Boolean(errors[field])),
    });

    return (
        <>
            <Head title="Daftar" />

            <div className="mx-auto flex max-w-md flex-col px-4 py-12 sm:py-16">
                <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
                    <h1 className="text-2xl font-bold text-slate-900">Daftar Penulis</h1>
                    <p className="mt-1 text-sm text-slate-600">
                        Buat akun untuk mulai menulis dan menerbitkan artikel Anda.
                    </p>

                    <form onSubmit={submit} noValidate className="mt-6 space-y-5">
                        <Field id="register-name" label="Nama lengkap" error={errors.name}>
                            <input type="text" {...bind('name', 'name')} />
                        </Field>

                        <Field
                            id="register-username"
                            label="Username"
                            error={errors.username}
                            hint="Huruf, angka, strip, dan garis bawah. Minimal 3 karakter."
                        >
                            <input type="text" {...bind('username', 'username')} />
                        </Field>

                        <Field
                            id="register-password"
                            label="Kata sandi"
                            error={errors.password}
                            hint="Minimal 8 karakter."
                        >
                            <input type="password" {...bind('password', 'new-password')} />
                        </Field>

                        <Field
                            id="register-password-confirmation"
                            label="Ulangi kata sandi"
                            error={errors.password_confirmation}
                        >
                            <input type="password" {...bind('password_confirmation', 'new-password')} />
                        </Field>

                        <Button
                            id="register-submit"
                            type="submit"
                            loading={processing}
                            icon={UserPlus}
                            className="w-full"
                        >
                            Daftar
                        </Button>
                    </form>

                    <p className="mt-6 text-center text-sm text-slate-600">
                        Sudah punya akun?{' '}
                        <Link href="/login" className="font-medium text-indigo-700 hover:underline">
                            Masuk
                        </Link>
                    </p>
                </div>
            </div>
        </>
    );
}

Register.layout = (page) => <AppLayout variant="public">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 3. Public/PostIndex
# ---------------------------------------------------------------
W 'resources/js/Pages/Public/PostIndex.jsx' @'
import { Head, Link, router, usePage } from '@inertiajs/react';
import { BookOpen, Calendar, LayoutDashboard, LogIn, Search, ShieldCheck, User, UserPlus } from 'lucide-react';
import { useEffect, useState } from 'react';
import { buttonClasses } from '../../Components/Button';
import Pagination from '../../Components/Pagination';
import { CategoryBadge } from '../../Components/Ui';
import { formatDate } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

function pillClass(active) {
    return `rounded-full border px-3 py-1 text-sm font-medium ${
        active
            ? 'border-indigo-600 bg-indigo-600 text-white'
            : 'border-slate-300 bg-white text-slate-700 hover:bg-slate-50'
    }`;
}

function ArticleCard({ post }) {
    return (
        <article className="group flex flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-xs transition hover:shadow-md">
            <Link href={`/articles/${post.slug}`} tabIndex={-1} aria-hidden="true" className="block">
                {post.cover_url ? (
                    <img
                        src={post.cover_url}
                        alt=""
                        loading="lazy"
                        className="aspect-video w-full object-cover"
                    />
                ) : (
                    <div className="flex aspect-video items-center justify-center bg-linear-to-br from-indigo-100 to-violet-100 text-indigo-400">
                        <BookOpen className="h-10 w-10" aria-hidden="true" />
                    </div>
                )}
            </Link>

            <div className="flex flex-1 flex-col p-5">
                <div>
                    <CategoryBadge category={post.category} />
                </div>
                <h3 className="mt-3 text-lg font-semibold leading-snug text-slate-900">
                    <Link href={`/articles/${post.slug}`} className="hover:text-indigo-700">
                        {post.title}
                    </Link>
                </h3>
                {post.excerpt && (
                    <p className="mt-2 line-clamp-3 text-sm text-slate-600">{post.excerpt}</p>
                )}
                <div className="mt-auto flex flex-wrap items-center gap-x-4 gap-y-1 pt-4 text-xs text-slate-500">
                    <span className="inline-flex items-center gap-1">
                        <User className="h-3.5 w-3.5" aria-hidden="true" />
                        {post.author}
                    </span>
                    {post.published_at && (
                        <span className="inline-flex items-center gap-1">
                            <Calendar className="h-3.5 w-3.5" aria-hidden="true" />
                            {formatDate(post.published_at)}
                        </span>
                    )}
                </div>
            </div>
        </article>
    );
}

function Hero({ user }) {
    return (
        <section className="border-b border-slate-200 bg-linear-to-br from-indigo-50 via-white to-violet-50">
            <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-24">
                <h1 className="max-w-3xl text-4xl font-bold tracking-tight text-slate-900 sm:text-5xl">
                    Tempat gagasan menjadi tulisan yang dibaca banyak orang
                </h1>
                <p className="mt-5 max-w-2xl text-lg text-slate-600">
                    BlogVerse Pro mempertemukan penulis dan pembaca. Jelajahi artikel pilihan dari
                    berbagai kategori, atau bergabung dan terbitkan tulisan Anda sendiri.
                </p>

                <div className="mt-8 flex flex-wrap gap-3">
                    {user ? (
                        <Link
                            id="hero-dashboard"
                            href={user.is_admin ? '/admin/users' : '/dashboard/posts'}
                            className={buttonClasses('primary', 'lg')}
                        >
                            {user.is_admin ? (
                                <ShieldCheck className="h-5 w-5" aria-hidden="true" />
                            ) : (
                                <LayoutDashboard className="h-5 w-5" aria-hidden="true" />
                            )}
                            {user.is_admin ? 'Buka Panel Admin' : 'Buka Dashboard Penulis'}
                        </Link>
                    ) : (
                        <>
                            <Link id="hero-login" href="/login" className={buttonClasses('primary', 'lg')}>
                                <LogIn className="h-5 w-5" aria-hidden="true" />
                                Masuk
                            </Link>
                            <Link
                                id="hero-register"
                                href="/register"
                                className={buttonClasses('secondary', 'lg')}
                            >
                                <UserPlus className="h-5 w-5" aria-hidden="true" />
                                Daftar Penulis
                            </Link>
                        </>
                    )}
                </div>
            </div>
        </section>
    );
}

export default function PostIndex({ posts, filters, categories, isHome }) {
    const { auth } = usePage().props;
    const base = isHome ? '/' : '/articles';
    const [search, setSearch] = useState(filters.search ?? '');

    useEffect(() => {
        setSearch(filters.search ?? '');
    }, [filters.search]);

    function visit(params) {
        const query = {};

        if (params.search) {
            query.search = params.search;
        }

        if (params.category) {
            query.category = params.category;
        }

        router.get(base, query, { preserveScroll: true, preserveState: true });
    }

    function submit(event) {
        event.preventDefault();
        visit({ search: search.trim(), category: filters.category });
    }

    const hasFilter = Boolean(filters.search || filters.category);

    return (
        <>
            <Head title={isHome ? 'Beranda' : 'Artikel'}>
                <meta
                    name="description"
                    content="Baca artikel terbaru dari para penulis BlogVerse Pro."
                />
            </Head>

            {isHome && <Hero user={auth.user} />}

            <section id="artikel" className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
                {isHome ? (
                    <h2 className="text-2xl font-bold text-slate-900">Artikel Terbaru</h2>
                ) : (
                    <h1 className="text-3xl font-bold text-slate-900">Semua Artikel</h1>
                )}

                <form onSubmit={submit} role="search" className="mt-6 flex flex-col gap-3 sm:flex-row">
                    <div className="relative flex-1">
                        <label htmlFor="public-search" className="sr-only">
                            Cari artikel berdasarkan judul atau isi
                        </label>
                        <Search
                            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                            aria-hidden="true"
                        />
                        <input
                            id="public-search"
                            type="search"
                            value={search}
                            onChange={(event) => setSearch(event.target.value)}
                            placeholder="Cari judul atau isi artikel..."
                            className="block w-full rounded-lg border border-slate-300 py-2 pl-9 pr-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        />
                    </div>
                    <button
                        type="submit"
                        className="inline-flex items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-1"
                    >
                        <Search className="h-4 w-4" aria-hidden="true" />
                        Cari
                    </button>
                </form>

                <div className="mt-4 flex flex-wrap gap-2" role="group" aria-label="Filter kategori">
                    <button
                        type="button"
                        aria-pressed={!filters.category}
                        onClick={() => visit({ search: filters.search, category: '' })}
                        className={pillClass(!filters.category)}
                    >
                        Semua
                    </button>
                    {categories.map((category) => (
                        <button
                            key={category.value}
                            type="button"
                            title={category.label}
                            aria-pressed={filters.category === category.value}
                            onClick={() => visit({ search: filters.search, category: category.value })}
                            className={pillClass(filters.category === category.value)}
                        >
                            {category.value}
                        </button>
                    ))}
                </div>

                <p className="mt-6 text-sm text-slate-600" aria-live="polite">
                    {posts.total} artikel ditemukan
                    {hasFilter && (
                        <>
                            {' '}
                            &middot;{' '}
                            <Link href={base} className="font-medium text-indigo-700 hover:underline">
                                Hapus filter
                            </Link>
                        </>
                    )}
                </p>

                {posts.data.length === 0 ? (
                    <div className="mt-6 rounded-xl border border-dashed border-slate-300 bg-white p-12 text-center">
                        <BookOpen className="mx-auto h-10 w-10 text-slate-400" aria-hidden="true" />
                        <p className="mt-3 font-medium text-slate-900">Belum ada artikel yang cocok</p>
                        <p className="mt-1 text-sm text-slate-600">
                            Coba kata kunci atau kategori lain.
                        </p>
                    </div>
                ) : (
                    <div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                        {posts.data.map((post) => (
                            <ArticleCard key={post.id} post={post} />
                        ))}
                    </div>
                )}

                <Pagination paginator={posts} />
            </section>
        </>
    );
}

PostIndex.layout = (page) => <AppLayout variant="public">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 4. Public/PostShow
# ---------------------------------------------------------------
W 'resources/js/Pages/Public/PostShow.jsx' @'
import { Head, Link, usePage } from '@inertiajs/react';
import { ArrowLeft, Calendar, LayoutDashboard, LogIn, ShieldCheck, User, UserPlus } from 'lucide-react';
import { buttonClasses } from '../../Components/Button';
import MarkdownViewer from '../../Components/MarkdownViewer';
import { CategoryBadge } from '../../Components/Ui';
import { formatDate } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

function CommunityCard({ user }) {
    return (
        <section
            aria-labelledby="community-title"
            className="mt-14 rounded-2xl bg-linear-to-br from-indigo-600 to-violet-600 p-8 text-white sm:p-10"
        >
            <h2 id="community-title" className="text-2xl font-bold">
                Suka dengan tulisan ini?
            </h2>
            <p className="mt-2 max-w-xl text-indigo-100">
                Bergabunglah dengan komunitas BlogVerse Pro. Tulis artikel Anda sendiri, terbitkan,
                dan jangkau pembaca dari berbagai kalangan.
            </p>

            <div className="mt-6 flex flex-wrap gap-3">
                {user ? (
                    <Link
                        id="cta-dashboard"
                        href={user.is_admin ? '/admin/users' : '/dashboard/posts'}
                        className={buttonClasses('secondary', 'lg')}
                    >
                        {user.is_admin ? (
                            <ShieldCheck className="h-5 w-5" aria-hidden="true" />
                        ) : (
                            <LayoutDashboard className="h-5 w-5" aria-hidden="true" />
                        )}
                        {user.is_admin ? 'Buka Panel Admin' : 'Buka Dashboard Penulis'}
                    </Link>
                ) : (
                    <>
                        <Link id="cta-login" href="/login" className={buttonClasses('secondary', 'lg')}>
                            <LogIn className="h-5 w-5" aria-hidden="true" />
                            Masuk
                        </Link>
                        <Link
                            id="cta-register"
                            href="/register"
                            className={buttonClasses('ghost', 'lg', 'border border-white/60 text-white hover:bg-white/10')}
                        >
                            <UserPlus className="h-5 w-5" aria-hidden="true" />
                            Daftar Penulis
                        </Link>
                    </>
                )}
            </div>
        </section>
    );
}

export default function PostShow({ post }) {
    const { auth } = usePage().props;

    return (
        <>
            <Head title={post.title}>
                {post.excerpt && <meta name="description" content={post.excerpt} />}
            </Head>

            <article className="mx-auto max-w-4xl px-4 py-10 sm:px-6">
                <Link
                    href="/articles"
                    className="inline-flex items-center gap-1 text-sm font-medium text-indigo-700 hover:underline"
                >
                    <ArrowLeft className="h-4 w-4" aria-hidden="true" />
                    Kembali ke daftar artikel
                </Link>

                <header className="mt-6">
                    <CategoryBadge category={post.category} />
                    <h1 className="mt-3 text-3xl font-bold leading-tight text-slate-900 sm:text-4xl">
                        {post.title}
                    </h1>
                    {post.excerpt && <p className="mt-4 text-lg text-slate-600">{post.excerpt}</p>}
                    <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-1 text-sm text-slate-500">
                        <span className="inline-flex items-center gap-1.5">
                            <User className="h-4 w-4" aria-hidden="true" />
                            {post.author}
                        </span>
                        {post.published_at && (
                            <span className="inline-flex items-center gap-1.5">
                                <Calendar className="h-4 w-4" aria-hidden="true" />
                                {formatDate(post.published_at)}
                            </span>
                        )}
                    </div>
                </header>

                {post.cover_url && (
                    <img
                        src={post.cover_url}
                        alt={`Sampul artikel: ${post.title}`}
                        className="mt-8 w-full rounded-xl object-cover"
                    />
                )}

                <div className="mt-8 rounded-xl border border-slate-200 bg-white p-5 sm:p-8">
                    <MarkdownViewer content={post.content} />
                </div>

                <CommunityCard user={auth.user} />
            </article>
        </>
    );
}

PostShow.layout = (page) => <AppLayout variant="public">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 5. Profile/Edit
# ---------------------------------------------------------------
W 'resources/js/Pages/Profile/Edit.jsx' @'
import { Head, useForm } from '@inertiajs/react';
import { Camera, Save } from 'lucide-react';
import { useEffect, useState } from 'react';
import Button from '../../Components/Button';
import Field, { inputClass } from '../../Components/Field';
import { PageHeader } from '../../Components/Ui';
import { initials } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_BYTES = 2 * 1024 * 1024;

export default function Edit({ profile }) {
    const { data, setData, post, processing, errors, reset, transform } = useForm({
        name: profile.name,
        username: profile.username,
        password: '',
        password_confirmation: '',
        photo: null,
        remove_photo: false,
    });
    const [previewUrl, setPreviewUrl] = useState(null);
    const [photoError, setPhotoError] = useState('');
    const [fileKey, setFileKey] = useState(0);

    useEffect(() => {
        if (!data.photo) {
            setPreviewUrl(null);

            return undefined;
        }

        const url = URL.createObjectURL(data.photo);
        setPreviewUrl(url);

        return () => URL.revokeObjectURL(url);
    }, [data.photo]);

    function onPhotoChange(event) {
        const file = event.target.files?.[0] ?? null;

        setPhotoError('');

        if (!file) {
            setData('photo', null);

            return;
        }

        if (!ALLOWED_TYPES.includes(file.type)) {
            setPhotoError('Foto profil harus berformat JPG, PNG, atau WEBP.');
            setData('photo', null);
            setFileKey((key) => key + 1);

            return;
        }

        if (file.size > MAX_BYTES) {
            setPhotoError('Ukuran foto profil maksimal 2 MB.');
            setData('photo', null);
            setFileKey((key) => key + 1);

            return;
        }

        setData((current) => ({ ...current, photo: file, remove_photo: false }));
    }

    function submit(event) {
        event.preventDefault();

        // Unggahan berkas tidak terbaca pada PUT asli, jadi gunakan POST + _method=put.
        transform((payload) => ({
            ...payload,
            _method: 'put',
            remove_photo: payload.remove_photo ? 1 : 0,
        }));

        post('/profile', {
            forceFormData: true,
            preserveScroll: true,
            onSuccess: () => {
                reset('password', 'password_confirmation', 'photo', 'remove_photo');
                setFileKey((key) => key + 1);
            },
        });
    }

    const shownPhoto = data.remove_photo ? null : (previewUrl ?? profile.photo_url);
    const photoMessage = photoError || errors.photo;

    const bind = (field, autoComplete) => ({
        id: `profile-${field.replace('_', '-')}`,
        name: field,
        autoComplete,
        value: data[field],
        onChange: (event) => setData(field, event.target.value),
        'aria-invalid': Boolean(errors[field]),
        'aria-describedby': errors[field] ? `profile-${field.replace('_', '-')}-error` : undefined,
        className: inputClass(Boolean(errors[field])),
    });

    return (
        <>
            <Head title="Profil" />

            <PageHeader title="Profil" description="Perbarui nama, username, kata sandi, dan foto profil Anda." />

            <form
                onSubmit={submit}
                noValidate
                className="max-w-2xl space-y-6 rounded-xl border border-slate-200 bg-white p-6 shadow-xs"
            >
                <section aria-labelledby="photo-title" className="flex flex-col gap-4 sm:flex-row sm:items-center">
                    {shownPhoto ? (
                        <img
                            src={shownPhoto}
                            alt="Foto profil"
                            className="h-24 w-24 rounded-full border border-slate-200 object-cover"
                        />
                    ) : (
                        <span
                            aria-hidden="true"
                            className="flex h-24 w-24 items-center justify-center rounded-full bg-indigo-600 text-2xl font-semibold text-white"
                        >
                            {initials(data.name)}
                        </span>
                    )}

                    <div className="flex-1">
                        <h2 id="photo-title" className="text-sm font-medium text-slate-700">
                            Foto profil
                        </h2>
                        <label
                            htmlFor="profile-photo"
                            className="mt-2 inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50 focus-within:ring-2 focus-within:ring-indigo-500"
                        >
                            <Camera className="h-4 w-4" aria-hidden="true" />
                            Pilih foto
                            <input
                                key={fileKey}
                                id="profile-photo"
                                name="photo"
                                type="file"
                                accept="image/jpeg,image/png,image/webp"
                                onChange={onPhotoChange}
                                aria-invalid={Boolean(photoMessage)}
                                aria-describedby={photoMessage ? 'profile-photo-error' : 'profile-photo-hint'}
                                className="sr-only"
                            />
                        </label>
                        {data.photo && (
                            <span className="ml-3 text-sm text-slate-600">{data.photo.name}</span>
                        )}

                        {photoMessage ? (
                            <p id="profile-photo-error" role="alert" className="mt-1 text-sm text-red-600">
                                {photoMessage}
                            </p>
                        ) : (
                            <p id="profile-photo-hint" className="mt-1 text-xs text-slate-500">
                                JPG, PNG, atau WEBP. Maksimal 2 MB.
                            </p>
                        )}

                        {profile.photo_url && !data.photo && (
                            <label className="mt-3 flex items-center gap-2 text-sm text-slate-700">
                                <input
                                    id="profile-remove-photo"
                                    type="checkbox"
                                    checked={data.remove_photo}
                                    onChange={(event) => setData('remove_photo', event.target.checked)}
                                    className="h-4 w-4 rounded border-slate-300 text-red-600 focus:ring-red-500"
                                />
                                Hapus foto profil
                            </label>
                        )}
                    </div>
                </section>

                <Field id="profile-name" label="Nama lengkap" error={errors.name}>
                    <input type="text" {...bind('name', 'name')} />
                </Field>

                <Field id="profile-username" label="Username" error={errors.username}>
                    <input type="text" {...bind('username', 'username')} />
                </Field>

                <fieldset className="space-y-5 rounded-lg border border-slate-200 p-4">
                    <legend className="px-1 text-sm font-medium text-slate-700">
                        Ganti kata sandi (opsional)
                    </legend>

                    <Field
                        id="profile-password"
                        label="Kata sandi baru"
                        error={errors.password}
                        hint="Kosongkan jika tidak ingin mengubah. Minimal 8 karakter."
                    >
                        <input type="password" {...bind('password', 'new-password')} />
                    </Field>

                    <Field
                        id="profile-password-confirmation"
                        label="Ulangi kata sandi baru"
                        error={errors.password_confirmation}
                    >
                        <input type="password" {...bind('password_confirmation', 'new-password')} />
                    </Field>
                </fieldset>

                <div className="flex justify-end">
                    <Button id="profile-submit" type="submit" loading={processing} icon={Save}>
                        Simpan Perubahan
                    </Button>
                </div>
            </form>
        </>
    );
}

Edit.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 6. Cek bundle (sintaks + import) untuk seluruh file JS selain app.jsx
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
# 7. Build Vite penuh (Tailwind + React + TOAST UI)
# ---------------------------------------------------------------
Write-Host ">> npm run build" -ForegroundColor Cyan
npm run build
if ($LASTEXITCODE -ne 0) {
  Write-Host "GAGAL: npm run build (exit code $LASTEXITCODE)" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "FASE 4b SELESAI." -ForegroundColor Green