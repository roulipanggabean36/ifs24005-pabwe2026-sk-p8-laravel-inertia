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