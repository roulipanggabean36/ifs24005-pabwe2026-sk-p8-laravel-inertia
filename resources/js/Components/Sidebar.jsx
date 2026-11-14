import { Link, router, usePage } from '@inertiajs/react';
import { BookOpen, FileText, House, LogOut, User, Users } from 'lucide-react';
import { initials } from '../lib/format';

const memberNav = [
    { href: '/dashboard/posts', label: 'Artikel Saya', icon: FileText },
    { href: '/profile', label: 'Profil', icon: User },
];

const adminNav = [
    { href: '/admin/users', label: 'Pengguna', icon: Users },
    { href: '/admin/posts', label: 'Semua Artikel', icon: FileText },
    { href: '/profile', label: 'Profil', icon: User },
];

export default function Sidebar({ open, onClose }) {
    const page = usePage();
    const user = page.props.auth.user;
    const path = page.url.split('?')[0];
    const items = user?.is_admin ? adminNav : memberNav;

    const isActive = (href) => path === href || path.startsWith(`${href}/`);

    return (
        <>
            {open && (
                <div
                    className="fixed inset-0 z-30 bg-slate-900/50 lg:hidden"
                    onClick={onClose}
                    aria-hidden="true"
                />
            )}

            <aside
                aria-label="Menu samping"
                className={`fixed inset-y-0 left-0 z-40 flex w-64 flex-col bg-slate-900 text-slate-100 transition-transform lg:translate-x-0 ${
                    open ? 'translate-x-0' : '-translate-x-full'
                }`}
            >
                <Link
                    href="/"
                    onClick={onClose}
                    className="flex h-16 items-center gap-2 px-5 text-lg font-bold text-white"
                >
                    <BookOpen className="h-6 w-6 text-indigo-400" aria-hidden="true" />
                    BlogVerse Pro
                </Link>

                {user && (
                    <div className="mx-4 mb-4 flex items-center gap-3 rounded-lg bg-slate-800 p-3">
                        {user.photo_url ? (
                            <img src={user.photo_url} alt="" className="h-10 w-10 rounded-full object-cover" />
                        ) : (
                            <span
                                aria-hidden="true"
                                className="flex h-10 w-10 items-center justify-center rounded-full bg-indigo-600 text-sm font-semibold text-white"
                            >
                                {initials(user.name)}
                            </span>
                        )}
                        <div className="min-w-0">
                            <p className="truncate text-sm font-medium text-white">{user.name}</p>
                            <p className="truncate text-xs text-slate-400">
                                @{user.username} &middot; {user.is_admin ? 'Admin' : 'Penulis'}
                            </p>
                        </div>
                    </div>
                )}

                <nav className="flex-1 space-y-1 overflow-y-auto px-3" aria-label="Navigasi dashboard">
                    {items.map((item) => {
                        const Icon = item.icon;

                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                onClick={onClose}
                                aria-current={isActive(item.href) ? 'page' : undefined}
                                className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium ${
                                    isActive(item.href)
                                        ? 'bg-indigo-600 text-white'
                                        : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                                }`}
                            >
                                <Icon className="h-5 w-5" aria-hidden="true" />
                                {item.label}
                            </Link>
                        );
                    })}

                    <Link
                        href="/"
                        onClick={onClose}
                        className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-slate-300 hover:bg-slate-800 hover:text-white"
                    >
                        <House className="h-5 w-5" aria-hidden="true" />
                        Beranda Publik
                    </Link>
                </nav>

                <div className="border-t border-slate-800 p-3">
                    <button
                        type="button"
                        onClick={() => router.post('/logout')}
                        className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-slate-300 hover:bg-slate-800 hover:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400"
                    >
                        <LogOut className="h-5 w-5" aria-hidden="true" />
                        Keluar
                    </button>
                </div>
            </aside>
        </>
    );
}