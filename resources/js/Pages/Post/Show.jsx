import { Head, Link, router } from '@inertiajs/react';
import { ArrowLeft, Calendar, EyeOff, ExternalLink, Globe, Pencil, Trash2 } from 'lucide-react';
import { useState } from 'react';
import Button, { buttonClasses } from '../../Components/Button';
import ConfirmDialog from '../../Components/ConfirmDialog';
import CoverUploader from '../../Components/CoverUploader';
import MarkdownViewer from '../../Components/MarkdownViewer';
import PostFormModal from '../../Components/PostFormModal';
import { CategoryBadge, StatusBadge } from '../../Components/Ui';
import { formatDate } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

export default function Show({ post, categories }) {
    const [editOpen, setEditOpen] = useState(false);
    const [deleteOpen, setDeleteOpen] = useState(false);
    const [deleting, setDeleting] = useState(false);
    const [toggling, setToggling] = useState(false);

    function togglePublish() {
        router.patch(
            `/dashboard/posts/${post.id}/publish`,
            {},
            {
                preserveScroll: true,
                onStart: () => setToggling(true),
                onFinish: () => setToggling(false),
            },
        );
    }

    function destroy() {
        router.delete(`/dashboard/posts/${post.id}`, {
            onStart: () => setDeleting(true),
            onFinish: () => {
                setDeleting(false);
                setDeleteOpen(false);
            },
        });
    }

    return (
        <>
            <Head title={post.title} />

            <Link
                href="/dashboard/posts"
                className="inline-flex items-center gap-1 text-sm font-medium text-indigo-700 hover:underline"
            >
                <ArrowLeft className="h-4 w-4" aria-hidden="true" />
                Kembali ke daftar artikel
            </Link>

            <header className="mt-4 rounded-xl border border-slate-200 bg-white p-6 shadow-xs">
                <div className="flex flex-wrap items-center gap-2">
                    <CategoryBadge category={post.category} />
                    <StatusBadge published={post.is_published} />
                </div>

                <h1 className="mt-3 text-2xl font-bold text-slate-900 sm:text-3xl">{post.title}</h1>

                {post.excerpt && <p className="mt-3 text-slate-600">{post.excerpt}</p>}

                <dl className="mt-4 flex flex-wrap gap-x-6 gap-y-1 text-sm text-slate-500">
                    <div className="inline-flex items-center gap-1.5">
                        <Calendar className="h-4 w-4" aria-hidden="true" />
                        <dt className="sr-only">Dibuat</dt>
                        <dd>Dibuat {formatDate(post.created_at)}</dd>
                    </div>
                    <div>
                        <dt className="sr-only">Diperbarui</dt>
                        <dd>Diperbarui {formatDate(post.updated_at)}</dd>
                    </div>
                    {post.is_published && post.published_at && (
                        <div>
                            <dt className="sr-only">Dipublikasikan</dt>
                            <dd>Terbit {formatDate(post.published_at)}</dd>
                        </div>
                    )}
                </dl>

                <div className="mt-5 flex flex-wrap items-center gap-2">
                    <Button
                        id="btn-edit-post"
                        variant="warning"
                        icon={Pencil}
                        onClick={() => setEditOpen(true)}
                    >
                        Ubah
                    </Button>
                    <Button
                        variant={post.is_published ? 'secondary' : 'success'}
                        icon={post.is_published ? EyeOff : Globe}
                        loading={toggling}
                        onClick={togglePublish}
                    >
                        {post.is_published ? 'Jadikan Draf' : 'Publikasikan'}
                    </Button>
                    {post.is_published && (
                        <a
                            href={`/articles/${post.slug}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className={buttonClasses('secondary', 'md')}
                        >
                            <ExternalLink className="h-4 w-4" aria-hidden="true" />
                            Lihat di halaman publik
                        </a>
                    )}
                    <Button variant="danger" icon={Trash2} onClick={() => setDeleteOpen(true)}>
                        Hapus
                    </Button>
                </div>
            </header>

            <div className="mt-6">
                <CoverUploader post={post} />
            </div>

            <section
                aria-label="Isi artikel"
                className="mt-6 rounded-xl border border-slate-200 bg-white p-5 shadow-xs sm:p-8"
            >
                <MarkdownViewer content={post.content} />
            </section>

            {editOpen && (
                <PostFormModal
                    mode="edit"
                    article={post}
                    categories={categories}
                    onClose={() => setEditOpen(false)}
                />
            )}

            <ConfirmDialog
                open={deleteOpen}
                title="Hapus artikel?"
                message={`Artikel "${post.title}" akan dihapus permanen beserta foto sampulnya.`}
                loading={deleting}
                onConfirm={destroy}
                onCancel={() => setDeleteOpen(false)}
            />
        </>
    );
}

Show.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;