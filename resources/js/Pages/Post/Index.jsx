import { Head, Link, router, usePage } from '@inertiajs/react';
import {
    CircleCheck,
    Clock,
    Download,
    Eye,
    EyeOff,
    FileText,
    Globe,
    Pencil,
    Plus,
    Search,
    Sparkles,
    Trash2,
    Upload,
    X,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import AiGeneratorModal from '../../Components/AiGeneratorModal';
import Button, { buttonClasses } from '../../Components/Button';
import ConfirmDialog from '../../Components/ConfirmDialog';
import { inputClass } from '../../Components/Field';
import ImportModal from '../../Components/ImportModal';
import KebabMenu from '../../Components/KebabMenu';
import Pagination from '../../Components/Pagination';
import PostFormModal from '../../Components/PostFormModal';
import { CategoryBadge, PageHeader, StatCard, StatusBadge } from '../../Components/Ui';
import { formatDate } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

function PostRow({ post, toggling, onToggle, onEdit, onDelete }) {
    const items = [
        {
            label: 'Detail',
            icon: Eye,
            tone: 'primary',
            onClick: () => router.visit(`/dashboard/posts/${post.id}`),
        },
        { label: 'Ubah', icon: Pencil, tone: 'primary', onClick: onEdit },
        { label: 'Hapus', icon: Trash2, tone: 'danger', onClick: onDelete },
    ];

    return (
        <li className="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center sm:gap-4">
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
                    <Link
                        href={`/dashboard/posts/${post.id}`}
                        className="block truncate font-medium text-slate-900 hover:text-indigo-700"
                    >
                        {post.title}
                    </Link>
                    <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-slate-500">
                        <CategoryBadge category={post.category} />
                        <StatusBadge published={post.is_published} />
                        <span>
                            {post.is_published
                                ? `Terbit ${formatDate(post.published_at)}`
                                : `Dibuat ${formatDate(post.created_at)}`}
                        </span>
                    </div>
                </div>
            </div>

            <div className="flex items-center gap-2 self-end sm:self-auto">
                <Button
                    variant={post.is_published ? 'secondary' : 'success'}
                    size="sm"
                    icon={post.is_published ? EyeOff : Globe}
                    loading={toggling}
                    onClick={onToggle}
                >
                    {post.is_published ? 'Jadikan Draf' : 'Publikasikan'}
                </Button>
                <KebabMenu items={items} label={`Menu tindakan untuk ${post.title}`} />
            </div>
        </li>
    );
}

export default function Index({ posts, stats, filters, categories, aiMax }) {
    const { flash } = usePage().props;
    const importErrors = flash?.import_errors ?? [];

    const [search, setSearch] = useState(filters.search ?? '');
    const [createOpen, setCreateOpen] = useState(false);
    const [editId, setEditId] = useState(null);
    const [aiOpen, setAiOpen] = useState(false);
    const [importOpen, setImportOpen] = useState(false);
    const [deleteTarget, setDeleteTarget] = useState(null);
    const [deleting, setDeleting] = useState(false);
    const [togglingId, setTogglingId] = useState(null);
    const [showImportErrors, setShowImportErrors] = useState(importErrors.length > 0);

    useEffect(() => {
        setSearch(filters.search ?? '');
    }, [filters.search]);

    useEffect(() => {
        setShowImportErrors(importErrors.length > 0);
    }, [importErrors.length]);

    const editing = editId === null ? null : (posts.data.find((item) => item.id === editId) ?? null);

    function visit(next) {
        const merged = { ...filters, ...next };
        const query = {};

        ['search', 'category', 'status'].forEach((key) => {
            if (merged[key]) {
                query[key] = merged[key];
            }
        });

        router.get('/dashboard/posts', query, { preserveScroll: true, preserveState: true });
    }

    function submitSearch(event) {
        event.preventDefault();
        visit({ search: search.trim() });
    }

    function togglePublish(post) {
        router.patch(
            `/dashboard/posts/${post.id}/publish`,
            {},
            {
                preserveScroll: true,
                onStart: () => setTogglingId(post.id),
                onFinish: () => setTogglingId(null),
            },
        );
    }

    function confirmDelete() {
        router.delete(`/dashboard/posts/${deleteTarget.id}`, {
            preserveScroll: true,
            onStart: () => setDeleting(true),
            onFinish: () => {
                setDeleting(false);
                setDeleteTarget(null);
            },
        });
    }

    const hasFilter = Boolean(filters.search || filters.category || filters.status);

    return (
        <>
            <Head title="Artikel Saya" />

            <PageHeader
                title="Artikel Saya"
                description="Kelola artikel yang Anda tulis: buat, ubah, terbitkan, impor, dan ekspor."
                actions={
                    <>
                        <Button
                            id="btn-create-post"
                            icon={Plus}
                            onClick={() => setCreateOpen(true)}
                        >
                            Tambah Artikel
                        </Button>
                        <Button
                            id="btn-ai-generate"
                            variant="violet"
                            icon={Sparkles}
                            onClick={() => setAiOpen(true)}
                        >
                            Generate AI
                        </Button>
                        <Button
                            id="btn-import-posts"
                            variant="secondary"
                            icon={Upload}
                            onClick={() => setImportOpen(true)}
                        >
                            Impor Excel
                        </Button>
                        <a
                            id="btn-export-posts"
                            href="/dashboard/posts/export"
                            className={buttonClasses('secondary', 'md')}
                        >
                            <Download className="h-4 w-4" aria-hidden="true" />
                            Ekspor Excel
                        </a>
                    </>
                }
            />

            <section aria-label="Ringkasan statistik artikel" className="grid gap-4 sm:grid-cols-3">
                <StatCard
                    label="Total Artikel"
                    value={stats.total}
                    icon={FileText}
                    tone="indigo"
                    active={!filters.status}
                    onClick={() => visit({ status: '' })}
                />
                <StatCard
                    label="Total Selesai"
                    value={stats.published}
                    icon={CircleCheck}
                    tone="emerald"
                    active={filters.status === 'published'}
                    onClick={() => visit({ status: 'published' })}
                />
                <StatCard
                    label="Belum Selesai"
                    value={stats.draft}
                    icon={Clock}
                    tone="amber"
                    active={filters.status === 'draft'}
                    onClick={() => visit({ status: 'draft' })}
                />
            </section>

            {showImportErrors && importErrors.length > 0 && (
                <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 p-4">
                    <div className="flex items-start justify-between gap-3">
                        <p className="font-medium text-red-800">
                            {importErrors.length} baris gagal diimpor
                        </p>
                        <button
                            type="button"
                            onClick={() => setShowImportErrors(false)}
                            aria-label="Tutup laporan impor"
                            className="rounded p-0.5 text-red-700 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-500"
                        >
                            <X className="h-4 w-4" aria-hidden="true" />
                        </button>
                    </div>
                    <ul className="mt-2 max-h-48 space-y-1 overflow-y-auto text-sm text-red-700">
                        {importErrors.map((item, index) => (
                            <li key={`${item.row}-${index}`}>
                                Baris {item.row}: {item.message}
                            </li>
                        ))}
                    </ul>
                </div>
            )}

            <section className="mt-6" aria-label="Daftar artikel">
                <form
                    onSubmit={submitSearch}
                    role="search"
                    className="flex flex-col gap-3 sm:flex-row"
                >
                    <div className="relative flex-1">
                        <label htmlFor="filter-search" className="sr-only">
                            Cari artikel berdasarkan judul atau isi
                        </label>
                        <Search
                            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                            aria-hidden="true"
                        />
                        <input
                            id="filter-search"
                            type="search"
                            value={search}
                            onChange={(event) => setSearch(event.target.value)}
                            placeholder="Cari judul atau isi artikel..."
                            className={`${inputClass(false)} pl-9`}
                        />
                    </div>

                    <div>
                        <label htmlFor="filter-category" className="sr-only">
                            Filter kategori
                        </label>
                        <select
                            id="filter-category"
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

                    <Button type="submit" icon={Search}>
                        Cari
                    </Button>
                </form>

                <p className="mt-4 text-sm text-slate-600" aria-live="polite">
                    {posts.total} artikel ditemukan
                    {hasFilter && (
                        <>
                            {' '}
                            &middot;{' '}
                            <Link
                                href="/dashboard/posts"
                                className="font-medium text-indigo-700 hover:underline"
                            >
                                Hapus filter
                            </Link>
                        </>
                    )}
                </p>

                {posts.data.length === 0 ? (
                    <div className="mt-4 rounded-xl border border-dashed border-slate-300 bg-white p-12 text-center">
                        <FileText className="mx-auto h-10 w-10 text-slate-400" aria-hidden="true" />
                        <p className="mt-3 font-medium text-slate-900">
                            {hasFilter ? 'Tidak ada artikel yang cocok' : 'Belum ada artikel'}
                        </p>
                        <p className="mt-1 text-sm text-slate-600">
                            {hasFilter
                                ? 'Coba ubah kata kunci atau filter Anda.'
                                : 'Mulai menulis artikel pertama Anda sekarang.'}
                        </p>
                        {!hasFilter && (
                            <div className="mt-4">
                                <Button icon={Plus} onClick={() => setCreateOpen(true)}>
                                    Tambah Artikel
                                </Button>
                            </div>
                        )}
                    </div>
                ) : (
                    <div className="mt-4 rounded-xl border border-slate-200 bg-white shadow-xs">
                        <ul className="divide-y divide-slate-100">
                            {posts.data.map((post) => (
                                <PostRow
                                    key={post.id}
                                    post={post}
                                    toggling={togglingId === post.id}
                                    onToggle={() => togglePublish(post)}
                                    onEdit={() => setEditId(post.id)}
                                    onDelete={() => setDeleteTarget(post)}
                                />
                            ))}
                        </ul>
                    </div>
                )}

                <Pagination paginator={posts} />
            </section>

            {createOpen && (
                <PostFormModal
                    mode="create"
                    categories={categories}
                    onClose={() => setCreateOpen(false)}
                />
            )}

            {editing && (
                <PostFormModal
                    key={editing.id}
                    mode="edit"
                    article={editing}
                    categories={categories}
                    onClose={() => setEditId(null)}
                />
            )}

            {aiOpen && <AiGeneratorModal max={aiMax} onClose={() => setAiOpen(false)} />}

            {importOpen && <ImportModal onClose={() => setImportOpen(false)} />}

            <ConfirmDialog
                open={deleteTarget !== null}
                title="Hapus artikel?"
                message={`Artikel "${deleteTarget?.title ?? ''}" akan dihapus permanen beserta foto sampulnya.`}
                loading={deleting}
                onConfirm={confirmDelete}
                onCancel={() => setDeleteTarget(null)}
            />
        </>
    );
}

Index.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;