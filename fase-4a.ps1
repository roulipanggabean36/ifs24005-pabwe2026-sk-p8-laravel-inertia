# fase-4a.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path .\artisan)) {
  Write-Host "GAGAL: jalankan dari root proyek Laravel." -ForegroundColor Red
  exit 1
}
if (-not (Test-Path 'routes/web.php') -or -not (Select-String -Path 'routes/web.php' -Pattern 'AdminUserController' -Quiet)) {
  Write-Host "GAGAL: Fase 3c belum selesai (routes/web.php belum berisi rute aplikasi)." -ForegroundColor Red
  exit 1
}
if (-not (Test-Path 'node_modules/lucide-react') -or -not (Test-Path 'node_modules/@toast-ui/editor') -or -not (Test-Path 'node_modules/dompurify')) {
  Write-Host "GAGAL: dependensi npm belum lengkap (lucide-react, @toast-ui/editor, dompurify). Jalankan ulang fase-1.ps1." -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------
# 1. lib/*
# ---------------------------------------------------------------
W 'resources/js/lib/format.js' @'
const dateFormatter = new Intl.DateTimeFormat('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
});

export function formatDate(value) {
    if (!value) {
        return '';
    }

    const date = new Date(value);

    return Number.isNaN(date.getTime()) ? '' : dateFormatter.format(date);
}

export function initials(name) {
    const letters = (name || '?')
        .trim()
        .split(/\s+/)
        .slice(0, 2)
        .map((part) => part.charAt(0).toUpperCase())
        .join('');

    return letters || '?';
}
'@

W 'resources/js/lib/http.js' @'
function readCookie(name) {
    const match = document.cookie.split('; ').find((row) => row.startsWith(`${name}=`));

    return match ? decodeURIComponent(match.split('=').slice(1).join('=')) : null;
}

/**
 * POST JSON ke endpoint Laravel dengan token CSRF dari cookie XSRF-TOKEN.
 * Selalu mengembalikan { ok, status, data } dan tidak melempar error.
 */
export async function postJson(url, body) {
    let response;

    try {
        response = await fetch(url, {
            method: 'POST',
            credentials: 'same-origin',
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
                'X-Requested-With': 'XMLHttpRequest',
                'X-XSRF-TOKEN': readCookie('XSRF-TOKEN') ?? '',
            },
            body: JSON.stringify(body),
        });
    } catch {
        return {
            ok: false,
            status: 0,
            data: { message: 'Tidak dapat terhubung ke server. Periksa koneksi Anda.' },
        };
    }

    let data = {};

    try {
        data = await response.json();
    } catch {
        data = {};
    }

    return { ok: response.ok, status: response.status, data };
}

/**
 * Ambil pesan kesalahan pertama yang ramah pengguna dari hasil postJson.
 */
export function errorMessage(result) {
    const errors = result?.data?.errors;

    if (errors && typeof errors === 'object') {
        const first = Object.values(errors)[0];

        if (Array.isArray(first) && first.length > 0) {
            return String(first[0]);
        }
    }

    return result?.data?.message || 'Terjadi kesalahan. Silakan coba lagi.';
}
'@

W 'resources/js/lib/sanitize.js' @'
import DOMPurify from 'dompurify';

/**
 * Sanitasi HTML hasil render Markdown agar aman dari XSS.
 */
export function sanitizeHtml(html) {
    return DOMPurify.sanitize(html, { USE_PROFILES: { html: true } });
}
'@

W 'resources/js/lib/useDialog.js' @'
import { useEffect, useRef } from 'react';

const FOCUSABLE =
    'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Perilaku dialog aksesibel: fokus masuk, jebakan Tab, ESC menutup,
 * kunci scroll body, dan fokus dikembalikan saat ditutup.
 */
export default function useDialog(open, dialogRef, onClose) {
    const closeRef = useRef(onClose);

    useEffect(() => {
        closeRef.current = onClose;
    }, [onClose]);

    useEffect(() => {
        const dialog = dialogRef.current;

        if (!open || !dialog) {
            return undefined;
        }

        const previouslyFocused = document.activeElement;
        const previousOverflow = document.body.style.overflow;

        document.body.style.overflow = 'hidden';
        (dialog.querySelector('[data-autofocus]') ?? dialog).focus();

        function onKeyDown(event) {
            if (event.key === 'Escape') {
                event.stopPropagation();
                closeRef.current?.();

                return;
            }

            if (event.key !== 'Tab') {
                return;
            }

            const items = [...dialog.querySelectorAll(FOCUSABLE)].filter(
                (element) => element.offsetParent !== null,
            );

            if (items.length === 0) {
                event.preventDefault();

                return;
            }

            const first = items[0];
            const last = items[items.length - 1];

            if (event.shiftKey && document.activeElement === first) {
                event.preventDefault();
                last.focus();
            } else if (!event.shiftKey && document.activeElement === last) {
                event.preventDefault();
                first.focus();
            }
        }

        document.addEventListener('keydown', onKeyDown);

        return () => {
            document.removeEventListener('keydown', onKeyDown);
            document.body.style.overflow = previousOverflow;

            if (previouslyFocused && typeof previouslyFocused.focus === 'function') {
                previouslyFocused.focus();
            }
        };
    }, [open, dialogRef]);
}
'@

# ---------------------------------------------------------------
# 2. Components: dasar
# ---------------------------------------------------------------
W 'resources/js/Components/Spinner.jsx' @'
export default function Spinner({ className = 'h-4 w-4' }) {
    return (
        <svg
            className={`animate-spin ${className}`}
            viewBox="0 0 24 24"
            fill="none"
            aria-hidden="true"
        >
            <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
            />
            <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
            />
        </svg>
    );
}
'@

W 'resources/js/Components/Button.jsx' @'
import Spinner from './Spinner';

const variants = {
    primary: 'bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500',
    secondary:
        'border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 focus:ring-slate-400',
    danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500',
    success: 'bg-emerald-600 text-white hover:bg-emerald-700 focus:ring-emerald-500',
    warning: 'bg-amber-600 text-white hover:bg-amber-700 focus:ring-amber-500',
    violet: 'bg-violet-600 text-white hover:bg-violet-700 focus:ring-violet-500',
    ghost: 'text-slate-600 hover:bg-slate-100 focus:ring-slate-400',
};

const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
};

/**
 * Kelas tombol yang dapat dipakai juga pada <Link> atau <a>.
 */
export function buttonClasses(variant = 'primary', size = 'md', extra = '') {
    return [
        'inline-flex items-center justify-center gap-2 rounded-lg font-medium transition',
        'focus:outline-none focus:ring-2 focus:ring-offset-1',
        'disabled:cursor-not-allowed disabled:opacity-60',
        sizes[size] ?? sizes.md,
        variants[variant] ?? variants.primary,
        extra,
    ]
        .filter(Boolean)
        .join(' ');
}

export default function Button({
    type = 'button',
    variant = 'primary',
    size = 'md',
    loading = false,
    disabled = false,
    icon: Icon,
    className = '',
    children,
    ...props
}) {
    return (
        <button
            type={type}
            disabled={disabled || loading}
            aria-busy={loading}
            className={buttonClasses(variant, size, className)}
            {...props}
        >
            {loading ? <Spinner /> : Icon ? <Icon className="h-4 w-4" aria-hidden="true" /> : null}
            {children}
        </button>
    );
}
'@

W 'resources/js/Components/LoadingIndicator.jsx' @'
import { router } from '@inertiajs/react';
import { useEffect, useRef, useState } from 'react';
import Spinner from './Spinner';

/**
 * Top progress bar + floating pill "Memproses tindakan..." untuk setiap request Inertia.
 */
export default function LoadingIndicator() {
    const [active, setActive] = useState(false);
    const [width, setWidth] = useState(0);
    const tickRef = useRef(null);
    const hideRef = useRef(null);

    useEffect(() => {
        const stopTick = () => {
            if (tickRef.current !== null) {
                clearInterval(tickRef.current);
                tickRef.current = null;
            }
        };

        const offStart = router.on('start', () => {
            clearTimeout(hideRef.current);
            stopTick();
            setActive(true);
            setWidth(8);
            tickRef.current = setInterval(() => {
                setWidth((current) => current + (90 - current) * 0.12);
            }, 200);
        });

        const offFinish = router.on('finish', () => {
            stopTick();
            setWidth(100);
            hideRef.current = setTimeout(() => {
                setActive(false);
                setWidth(0);
            }, 300);
        });

        return () => {
            offStart();
            offFinish();
            stopTick();
            clearTimeout(hideRef.current);
        };
    }, []);

    return (
        <>
            <div className="pointer-events-none fixed inset-x-0 top-0 z-[60] h-1" aria-hidden="true">
                <div
                    className="h-full bg-indigo-600 transition-[width] duration-200 ease-out"
                    style={{ width: `${width}%`, opacity: active ? 1 : 0 }}
                />
            </div>

            {active && (
                <div
                    role="status"
                    aria-live="polite"
                    className="pointer-events-none fixed bottom-6 left-1/2 z-[60] flex -translate-x-1/2 items-center gap-2 rounded-full bg-slate-900 px-4 py-2 text-sm font-medium text-white shadow-lg"
                >
                    <Spinner />
                    Memproses tindakan...
                </div>
            )}
        </>
    );
}
'@

W 'resources/js/Components/FlashMessages.jsx' @'
import { usePage } from '@inertiajs/react';
import { CircleAlert, CircleCheck, X } from 'lucide-react';
import { useEffect, useState } from 'react';

export default function FlashMessages() {
    const { flash } = usePage().props;
    const [message, setMessage] = useState(null);

    useEffect(() => {
        if (flash?.success) {
            setMessage({ type: 'success', text: flash.success });
        } else if (flash?.error) {
            setMessage({ type: 'error', text: flash.error });
        }
    }, [flash]);

    useEffect(() => {
        if (!message) {
            return undefined;
        }

        const timer = setTimeout(() => setMessage(null), 5000);

        return () => clearTimeout(timer);
    }, [message]);

    if (!message) {
        return null;
    }

    const isError = message.type === 'error';
    const Icon = isError ? CircleAlert : CircleCheck;

    return (
        <div
            role={isError ? 'alert' : 'status'}
            className={`fixed right-4 top-4 z-[70] flex max-w-sm items-start gap-3 rounded-lg border px-4 py-3 text-sm shadow-lg ${
                isError
                    ? 'border-red-200 bg-red-50 text-red-800'
                    : 'border-emerald-200 bg-emerald-50 text-emerald-800'
            }`}
        >
            <Icon className="mt-0.5 h-5 w-5 shrink-0" aria-hidden="true" />
            <p className="flex-1">{message.text}</p>
            <button
                type="button"
                onClick={() => setMessage(null)}
                aria-label="Tutup notifikasi"
                className="rounded p-0.5 hover:bg-black/5 focus:outline-none focus:ring-2 focus:ring-current"
            >
                <X className="h-4 w-4" aria-hidden="true" />
            </button>
        </div>
    );
}
'@

W 'resources/js/Components/Modal.jsx' @'
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
'@

W 'resources/js/Components/ConfirmDialog.jsx' @'
import { useId, useRef } from 'react';
import useDialog from '../lib/useDialog';
import Button from './Button';

export default function ConfirmDialog({
    open,
    title,
    message,
    confirmLabel = 'Hapus',
    loading = false,
    onConfirm,
    onCancel,
}) {
    const titleId = useId();
    const descId = useId();
    const dialogRef = useRef(null);

    useDialog(open, dialogRef, onCancel);

    if (!open) {
        return null;
    }

    return (
        <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 p-4"
            onMouseDown={(event) => {
                if (event.target === event.currentTarget) {
                    onCancel();
                }
            }}
        >
            <div
                ref={dialogRef}
                role="alertdialog"
                aria-modal="true"
                aria-labelledby={titleId}
                aria-describedby={descId}
                tabIndex={-1}
                className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl focus:outline-none"
            >
                <h2 id={titleId} className="text-lg font-semibold text-slate-900">
                    {title}
                </h2>
                <p id={descId} className="mt-2 text-sm text-slate-600">
                    {message}
                </p>
                <div className="mt-6 flex justify-end gap-3">
                    <Button variant="secondary" onClick={onCancel} disabled={loading} data-autofocus>
                        Batal
                    </Button>
                    <Button variant="danger" onClick={onConfirm} loading={loading}>
                        {confirmLabel}
                    </Button>
                </div>
            </div>
        </div>
    );
}
'@

W 'resources/js/Components/Pagination.jsx' @'
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
'@

W 'resources/js/Components/KebabMenu.jsx' @'
import { EllipsisVertical } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

const tones = {
    primary: 'text-indigo-700 hover:bg-indigo-50',
    danger: 'text-red-600 hover:bg-red-50',
};

/**
 * Menu tindakan vertical dots (⋮).
 * items: [{ label, icon, onClick, tone: 'primary' | 'danger' }]
 */
export default function KebabMenu({ items, label = 'Menu tindakan' }) {
    const [open, setOpen] = useState(false);
    const rootRef = useRef(null);

    useEffect(() => {
        if (!open) {
            return undefined;
        }

        const onPointerDown = (event) => {
            if (rootRef.current && !rootRef.current.contains(event.target)) {
                setOpen(false);
            }
        };
        const onKeyDown = (event) => {
            if (event.key === 'Escape') {
                setOpen(false);
            }
        };

        document.addEventListener('mousedown', onPointerDown);
        document.addEventListener('keydown', onKeyDown);

        return () => {
            document.removeEventListener('mousedown', onPointerDown);
            document.removeEventListener('keydown', onKeyDown);
        };
    }, [open]);

    return (
        <div ref={rootRef} className="relative inline-block text-left">
            <button
                type="button"
                aria-label={label}
                aria-haspopup="menu"
                aria-expanded={open}
                onClick={() => setOpen((value) => !value)}
                className="rounded-lg p-2 text-slate-500 hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
                <EllipsisVertical className="h-5 w-5" aria-hidden="true" />
            </button>

            {open && (
                <div
                    role="menu"
                    className="absolute right-0 z-30 mt-1 w-44 rounded-lg border border-slate-200 bg-white py-1 shadow-lg"
                >
                    {items.map((item) => {
                        const Icon = item.icon;

                        return (
                            <button
                                key={item.label}
                                type="button"
                                role="menuitem"
                                onClick={() => {
                                    setOpen(false);
                                    item.onClick();
                                }}
                                className={`flex w-full items-center gap-2 px-3 py-2 text-left text-sm ${
                                    tones[item.tone ?? 'primary']
                                }`}
                            >
                                <Icon className="h-4 w-4" aria-hidden="true" />
                                {item.label}
                            </button>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
'@

W 'resources/js/Components/Field.jsx' @'
export function inputClass(hasError = false) {
    return `block w-full rounded-lg border px-3 py-2 text-sm text-slate-900 shadow-xs focus:outline-none focus:ring-2 disabled:bg-slate-100 ${
        hasError ? 'border-red-400 focus:ring-red-400' : 'border-slate-300 focus:ring-indigo-500'
    }`;
}

/**
 * Pembungkus label + kontrol + pesan kesalahan.
 * Kontrol di dalamnya sebaiknya memakai id yang sama dan aria-describedby="{id}-error".
 */
export default function Field({ id, label, error, hint, children }) {
    return (
        <div>
            <label htmlFor={id} className="mb-1 block text-sm font-medium text-slate-700">
                {label}
            </label>
            {children}
            {hint && !error && (
                <p id={`${id}-hint`} className="mt-1 text-xs text-slate-500">
                    {hint}
                </p>
            )}
            {error && (
                <p id={`${id}-error`} role="alert" className="mt-1 text-sm text-red-600">
                    {error}
                </p>
            )}
        </div>
    );
}
'@

W 'resources/js/Components/Ui.jsx' @'
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
'@

# ---------------------------------------------------------------
# 3. Components: Markdown (TOAST UI)
# ---------------------------------------------------------------
W 'resources/js/Components/MarkdownEditor.jsx' @'
import Editor from '@toast-ui/editor';
import '@toast-ui/editor/dist/toastui-editor.css';
import { useEffect, useRef } from 'react';
import { sanitizeHtml } from '../lib/sanitize';

/**
 * TOAST UI Editor (mode Markdown). Nilai awal dibaca sekali saat mount;
 * gunakan `key` untuk memaksa inisialisasi ulang. Dibersihkan saat unmount.
 */
export default function MarkdownEditor({
    value = '',
    onChange,
    height = '420px',
    placeholder = 'Tulis artikel dalam format Markdown...',
    label = 'Editor Markdown',
}) {
    const elRef = useRef(null);
    const changeRef = useRef(onChange);

    useEffect(() => {
        changeRef.current = onChange;
    }, [onChange]);

    useEffect(() => {
        let editor = null;

        editor = new Editor({
            el: elRef.current,
            initialValue: value ?? '',
            initialEditType: 'markdown',
            previewStyle: 'vertical',
            height,
            placeholder,
            usageStatistics: false,
            customHTMLSanitizer: sanitizeHtml,
            events: {
                change: () => {
                    if (editor) {
                        changeRef.current?.(editor.getMarkdown());
                    }
                },
            },
        });

        return () => {
            editor.destroy();
            editor = null;
        };
        // Nilai awal hanya dibaca saat mount.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    return <div ref={elRef} role="group" aria-label={label} />;
}
'@

W 'resources/js/Components/MarkdownViewer.jsx' @'
import Viewer from '@toast-ui/editor/dist/toastui-editor-viewer';
import '@toast-ui/editor/dist/toastui-editor-viewer.css';
import { useEffect, useRef } from 'react';
import { sanitizeHtml } from '../lib/sanitize';

/**
 * TOAST UI Viewer. Konten disanitasi dengan DOMPurify, dibersihkan saat unmount.
 */
export default function MarkdownViewer({ content }) {
    const elRef = useRef(null);

    useEffect(() => {
        const viewer = new Viewer({
            el: elRef.current,
            initialValue: content ?? '',
            customHTMLSanitizer: sanitizeHtml,
        });

        return () => viewer.destroy();
    }, [content]);

    return <div ref={elRef} />;
}
'@

# ---------------------------------------------------------------
# 4. Components: navigasi
# ---------------------------------------------------------------
W 'resources/js/Components/PublicNavbar.jsx' @'
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
'@

W 'resources/js/Components/PublicFooter.jsx' @'
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
'@

W 'resources/js/Components/Sidebar.jsx' @'
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
'@

# ---------------------------------------------------------------
# 5. Layout
# ---------------------------------------------------------------
W 'resources/js/Layouts/AppLayout.jsx' @'
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
'@

# ---------------------------------------------------------------
# 6. Cek sintaks + resolusi import (bundle percobaan dengan esbuild)
# ---------------------------------------------------------------
$root = (Get-Location).Path
$entries = Get-ChildItem resources/js -Recurse -File -Include *.jsx,*.js |
  Where-Object { $_.Name -ne 'app.jsx' }
$lines = foreach ($e in $entries) {
  $rel = $e.FullName.Substring($root.Length + 1).Replace('\', '/')
  "import './$rel';"
}
W 'tmp-check.jsx' ($lines -join "`n")

$out = Join-Path $env:TEMP 'esbuild-check.js'
$esArgs = @('tmp-check.jsx', '--bundle', "--outfile=$out", '--jsx=automatic',
            '--loader:.css=empty', '--platform=browser', '--log-level=error')
$esLocal = Join-Path $root 'node_modules\.bin\esbuild.cmd'
if (Test-Path $esLocal) { & $esLocal @esArgs } else { npx --yes esbuild @esArgs }
$esExit = $LASTEXITCODE
Remove-Item tmp-check.jsx -Force
if (Test-Path $out) { Remove-Item $out -Force }

if ($esExit -ne 0) {
  Write-Host "GAGAL: ada kesalahan sintaks atau import di file JSX (lihat pesan di atas)." -ForegroundColor Red
  exit 1
}
Write-Host "Cek bundle: sintaks dan semua import valid ($($entries.Count) file)." -ForegroundColor Green

Write-Host ""
Write-Host "FASE 4a SELESAI." -ForegroundColor Green