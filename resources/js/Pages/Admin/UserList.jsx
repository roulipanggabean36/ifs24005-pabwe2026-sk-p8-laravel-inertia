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