const statTones = {
    indigo: 'bg-indigo-50 text-indigo-600',
    emerald: 'bg-emerald-50 text-emerald-600',
    amber: 'bg-amber-50 text-amber-600',
};

/**
 * Kartu ringkasan statistik. Jika onClick diberikan, kartu menjadi tombol (filter interaktif).
 */
export function StatCard({ label, value, icon: Icon, tone = 'indigo', onClick, active = false }) {
    const base = 'flex items-center gap-4 rounded-xl border border-slate-200 bg-white p-5 shadow-xs';
    const content = (
        <>
            <span
                className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-lg ${statTones[tone]}`}
            >
                <Icon className="h-6 w-6" aria-hidden="true" />
            </span>
            <span>
                <span className="block text-sm text-slate-500">{label}</span>
                <span className="block text-2xl font-bold text-slate-900">{value}</span>
            </span>
        </>
    );

    if (!onClick) {
        return <div className={base}>{content}</div>;
    }

    return (
        <button
            type="button"
            onClick={onClick}
            aria-pressed={active}
            className={`${base} w-full text-left transition hover:border-indigo-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 ${
                active ? 'border-indigo-500 ring-1 ring-indigo-500' : ''
            }`}
        >
            {content}
        </button>
    );
}

export function PageHeader({ title, description, actions }) {
    return (
        <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
                <h1 className="text-2xl font-bold text-slate-900">{title}</h1>
                {description && <p className="mt-1 text-sm text-slate-600">{description}</p>}
            </div>
            {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
        </div>
    );
}

const categoryTones = {
    Teknologi: 'bg-sky-100 text-sky-800',
    Pendidikan: 'bg-emerald-100 text-emerald-800',
    'Gaya Hidup': 'bg-pink-100 text-pink-800',
    Bisnis: 'bg-amber-100 text-amber-800',
    Opini: 'bg-violet-100 text-violet-800',
    Umum: 'bg-slate-100 text-slate-700',
};

export function CategoryBadge({ category }) {
    return (
        <span
            className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                categoryTones[category] ?? categoryTones.Umum
            }`}
        >
            {category}
        </span>
    );
}

export function StatusBadge({ published }) {
    return (
        <span
            className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                published ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-200 text-slate-700'
            }`}
        >
            {published ? 'Terbit' : 'Draf'}
        </span>
    );
}