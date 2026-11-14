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