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