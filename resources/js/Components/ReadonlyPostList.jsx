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