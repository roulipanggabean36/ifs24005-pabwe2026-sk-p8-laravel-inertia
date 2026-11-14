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
                <h2 className="mt-3 text-lg font-semibold leading-snug text-slate-900">
                    <Link href={`/articles/${post.slug}`} className="hover:text-indigo-700">
                        {post.title}
                    </Link>
                </h2>
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