import { X } from 'lucide-react';
import { useId, useRef } from 'react';
import useDialog from '../lib/useDialog';

const tones = {
    create: {
        header: 'bg-indigo-700 text-white',
        footer: 'border-indigo-200 bg-indigo-50',
    },
    edit: {
        header: 'bg-amber-600 text-white',
        footer: 'border-amber-200 bg-amber-50',
    },
    ai: {
        header: 'bg-violet-700 text-white',
        footer: 'border-violet-200 bg-violet-50',
    },
};

/**
 * Modal Full Screen. Header dan footer berwarna kontras (per tone),
 * tombol aksi di sisi kanan footer. ESC menutup, fokus terjebak di dalam.
 */
export default function Modal({ open, title, tone = 'create', onClose, children, footer }) {
    const titleId = useId();
    const dialogRef = useRef(null);

    useDialog(open, dialogRef, onClose);

    if (!open) {
        return null;
    }

    const style = tones[tone] ?? tones.create;

    return (
        <div
            ref={dialogRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            tabIndex={-1}
            className="fixed inset-0 z-50 flex flex-col bg-white focus:outline-none"
        >
            <header className={`flex items-center justify-between px-4 py-3 sm:px-6 ${style.header}`}>
                <h2 id={titleId} className="text-lg font-semibold">
                    {title}
                </h2>
                <button
                    type="button"
                    onClick={onClose}
                    aria-label="Tutup"
                    className="rounded-lg p-2 hover:bg-white/20 focus:outline-none focus:ring-2 focus:ring-white"
                >
                    <X className="h-5 w-5" aria-hidden="true" />
                </button>
            </header>

            <div className="flex-1 overflow-y-auto px-4 py-6 sm:px-6">
                <div className="mx-auto w-full max-w-5xl">{children}</div>
            </div>

            {footer && (
                <footer
                    className={`flex flex-wrap items-center justify-end gap-3 border-t px-4 py-3 sm:px-6 ${style.footer}`}
                >
                    {footer}
                </footer>
            )}
        </div>
    );
}