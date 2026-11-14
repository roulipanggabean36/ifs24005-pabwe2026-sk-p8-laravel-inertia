import { Link } from '@inertiajs/react';
import { BookOpen, Menu } from 'lucide-react';
import { useState } from 'react';
import FlashMessages from '../Components/FlashMessages';
import LoadingIndicator from '../Components/LoadingIndicator';
import PublicFooter from '../Components/PublicFooter';
import PublicNavbar from '../Components/PublicNavbar';
import Sidebar from '../Components/Sidebar';

/**
 * variant="public"    : Sticky Top Navbar + layout baca full-width + footer editorial (tanpa sidebar).
 * variant="dashboard" : sidebar untuk Penulis dan Admin.
 *
 * Dipakai sebagai persistent layout: Page.layout = (page) => <AppLayout variant="...">{page}</AppLayout>
 */
export default function AppLayout({ variant = 'public', children }) {
    const [sidebarOpen, setSidebarOpen] = useState(false);

    return (
        <>
            <a
                href="#main-content"
                className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[80] focus:rounded-lg focus:bg-white focus:px-4 focus:py-2 focus:text-sm focus:shadow"
            >
                Lewati ke konten utama
            </a>

            <LoadingIndicator />
            <FlashMessages />

            {variant === 'dashboard' ? (
                <div className="min-h-screen bg-slate-100">
                    <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />

                    <div className="lg:pl-64">
                        <header className="sticky top-0 z-20 flex h-14 items-center gap-3 border-b border-slate-200 bg-white px-4 lg:hidden">
                            <button
                                type="button"
                                onClick={() => setSidebarOpen(true)}
                                aria-label="Buka menu samping"
                                className="rounded-lg p-2 text-slate-600 hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                            >
                                <Menu className="h-6 w-6" aria-hidden="true" />
                            </button>
                            <Link href="/" className="flex items-center gap-2 font-bold text-indigo-700">
                                <BookOpen className="h-5 w-5" aria-hidden="true" />
                                BlogVerse Pro
                            </Link>
                        </header>

                        <main id="main-content" className="mx-auto w-full max-w-6xl px-4 py-6 sm:px-6">
                            {children}
                        </main>
                    </div>
                </div>
            ) : (
                <div className="flex min-h-screen flex-col bg-slate-50">
                    <PublicNavbar />
                    <main id="main-content" className="flex-1">
                        {children}
                    </main>
                    <PublicFooter />
                </div>
            )}
        </>
    );
}