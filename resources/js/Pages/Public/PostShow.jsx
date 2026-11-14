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