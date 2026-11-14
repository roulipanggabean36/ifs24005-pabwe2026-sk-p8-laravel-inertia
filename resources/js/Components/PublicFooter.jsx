import { Link } from '@inertiajs/react';
import { BookOpen } from 'lucide-react';

export default function PublicFooter() {
    return (
        <footer className="border-t border-slate-200 bg-white">
            <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
                <div className="flex flex-col gap-6 md:flex-row md:items-start md:justify-between">
                    <div className="max-w-md">
                        <p className="flex items-center gap-2 text-lg font-bold text-indigo-700">
                            <BookOpen className="h-5 w-5" aria-hidden="true" />
                            BlogVerse Pro
                        </p>
                        <p className="mt-2 text-sm text-slate-600">
                            Platform publikasi artikel untuk penulis dan pembaca. Tulis, terbitkan,
                            dan bagikan gagasan Anda kepada dunia.
                        </p>
                    </div>

                    <nav aria-label="Navigasi footer">
                        <ul className="flex flex-wrap gap-x-6 gap-y-2 text-sm font-medium">
                            <li>
                                <Link href="/" className="text-slate-700 hover:text-indigo-700">
                                    Beranda Publik
                                </Link>
                            </li>
                            <li>
                                <Link href="/login" className="text-slate-700 hover:text-indigo-700">
                                    Halaman Login
                                </Link>
                            </li>
                            <li>
                                <Link href="/register" className="text-slate-700 hover:text-indigo-700">
                                    Halaman Register
                                </Link>
                            </li>
                        </ul>
                    </nav>
                </div>

                <p className="mt-8 border-t border-slate-100 pt-6 text-xs text-slate-500">
                    &copy; {new Date().getFullYear()} BlogVerse Pro. Seluruh hak cipta dilindungi.
                </p>
            </div>
        </footer>
    );
}