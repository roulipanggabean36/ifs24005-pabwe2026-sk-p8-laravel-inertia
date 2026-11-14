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