import { Link } from '@inertiajs/react';

export default function Pagination({ paginator }) {
    if (!paginator || paginator.last_page <= 1) {
        return null;
    }

    const links = paginator.links ?? [];
    const base =
        'inline-flex min-w-9 items-center justify-center rounded-lg border px-3 py-1.5 text-sm';

    return (
        <nav
            className="mt-6 flex flex-col items-center justify-between gap-3 sm:flex-row"
            aria-label="Navigasi halaman"
        >
            <p className="text-sm text-slate-600">
                Menampilkan {paginator.from ?? 0}-{paginator.to ?? 0} dari {paginator.total} data
            </p>

            <ul className="flex flex-wrap items-center gap-1">
                {links.map((link, index) => {
                    const isPrev = index === 0;
                    const isNext = index === links.length - 1;
                    const label = isPrev ? 'Sebelumnya' : isNext ? 'Berikutnya' : link.label;

                    if (link.url === null) {
                        return (
                            <li key={`${index}-${label}`}>
                                <span
                                    className={`${base} border-slate-200 bg-slate-50 text-slate-400`}
                                    aria-disabled="true"
                                >
                                    {label}
                                </span>
                            </li>
                        );
                    }

                    return (
                        <li key={`${index}-${label}`}>
                            <Link
                                href={link.url}
                                preserveScroll
                                aria-current={link.active ? 'page' : undefined}
                                className={`${base} ${
                                    link.active
                                        ? 'border-indigo-600 bg-indigo-600 text-white'
                                        : 'border-slate-300 bg-white text-slate-700 hover:bg-slate-50'
                                }`}
                            >
                                {label}
                            </Link>
                        </li>
                    );
                })}
            </ul>
        </nav>
    );
}