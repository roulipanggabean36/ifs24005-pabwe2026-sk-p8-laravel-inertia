import { Link, usePage } from '@inertiajs/react';
import { BookOpen, LayoutDashboard, LogIn, Menu, ShieldCheck, UserPlus, X } from 'lucide-react';
import { useState } from 'react';
import { initials } from '../lib/format';
import { buttonClasses } from './Button';

function Avatar({ user }) {
    if (user.photo_url) {
        return <img src={user.photo_url} alt="" className="h-8 w-8 rounded-full object-cover" />;
    }

    return (
        <span
            aria-hidden="true"
            className="flex h-8 w-8 items-center justify-center rounded-full bg-indigo-600 text-xs font-semibold text-white"
        >
            {initials(user.name)}
        </span>
    );
}

function AuthActions({ user, onNavigate }) {
    if (user) {
        const Icon = user.is_admin ? ShieldCheck : LayoutDashboard;

        return (
            <Link
                id="nav-dashboard"
                href={user.is_admin ? '/admin/users' : '/dashboard/posts'}
                onClick={onNavigate}
                className="inline-flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50"
            >
                <Avatar user={user} />
                <span>{user.is_admin ? 'Panel Admin' : 'Dashboard Penulis'}</span>
                <Icon className="h-4 w-4" aria-hidden="true" />
            </Link>
        );
    }

    return (
        <>
            <Link
                id="nav-login"
                href="/login"
                onClick={onNavigate}
                className={buttonClasses('secondary', 'sm')}
            >
                <LogIn className="h-4 w-4" aria-hidden="true" />
                Masuk
            </Link>
            <Link
                id="nav-register"
                href="/register"
                onClick={onNavigate}
                className={buttonClasses('primary', 'sm')}
            >
                <UserPlus className="h-4 w-4" aria-hidden="true" />
                Daftar
            </Link>
        </>
    );
}

export default function PublicNavbar() {
    const page = usePage();
    const user = page.props.auth.user;
    const path = page.url.split('?')[0];
    const [open, setOpen] = useState(false);

    const links = [
        { href: '/', label: 'Beranda' },
        { href: '/articles', label: 'Artikel' },
    ];

    const linkClass = (href) =>
        `rounded-lg px-3 py-1.5 text-sm font-medium ${
            path === href
                ? 'bg-indigo-50 text-indigo-700'
                : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
        }`;

    return (
        <header className="sticky top-0 z-40 border-b border-slate-200 bg-white/90 backdrop-blur">
            <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
                <Link href="/" className="flex items-center gap-2 text-lg font-bold text-indigo-700">
                    <BookOpen className="h-6 w-6" aria-hidden="true" />
                    BlogVerse Pro
                </Link>

                <nav className="hidden items-center gap-2 sm:flex" aria-label="Navigasi utama">
                    {links.map((link) => (
                        <Link key={link.href} href={link.href} className={linkClass(link.href)}>
                            {link.label}
                        </Link>
                    ))}
                    <span className="mx-1 h-6 w-px bg-slate-200" aria-hidden="true" />
                    <AuthActions user={user} />
                </nav>

                <button
                    type="button"
                    className="rounded-lg p-2 text-slate-600 hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500 sm:hidden"
                    aria-label={open ? 'Tutup menu' : 'Buka menu'}
                    aria-expanded={open}
                    onClick={() => setOpen((value) => !value)}
                >
                    {open ? (
                        <X className="h-6 w-6" aria-hidden="true" />
                    ) : (
                        <Menu className="h-6 w-6" aria-hidden="true" />
                    )}
                </button>
            </div>

            {open && (
                <nav
                    className="flex flex-col gap-2 border-t border-slate-200 bg-white px-4 py-3 sm:hidden"
                    aria-label="Navigasi seluler"
                >
                    {links.map((link) => (
                        <Link
                            key={link.href}
                            href={link.href}
                            onClick={() => setOpen(false)}
                            className={linkClass(link.href)}
                        >
                            {link.label}
                        </Link>
                    ))}
                    <div className="flex flex-wrap items-center gap-2 pt-2">
                        <AuthActions user={user} onNavigate={() => setOpen(false)} />
                    </div>
                </nav>
            )}
        </header>
    );
}