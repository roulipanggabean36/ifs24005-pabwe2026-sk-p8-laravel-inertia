import { router } from '@inertiajs/react';
import { Upload } from 'lucide-react';
import { useId, useRef, useState } from 'react';
import useDialog from '../lib/useDialog';
import Button from './Button';

const MAX_BYTES = 5 * 1024 * 1024;

export default function ImportModal({ onClose }) {
    const titleId = useId();
    const dialogRef = useRef(null);
    const [file, setFile] = useState(null);
    const [error, setError] = useState('');
    const [processing, setProcessing] = useState(false);

    useDialog(true, dialogRef, onClose);

    function onChange(event) {
        const picked = event.target.files?.[0] ?? null;

        setError('');

        if (!picked) {
            setFile(null);

            return;
        }

        if (!/\.(xlsx|xls)$/i.test(picked.name)) {
            setError('Berkas harus berformat .xlsx atau .xls.');
            setFile(null);
            event.target.value = '';

            return;
        }

        if (picked.size > MAX_BYTES) {
            setError('Ukuran berkas maksimal 5 MB.');
            setFile(null);
            event.target.value = '';

            return;
        }

        setFile(picked);
    }

    function submit(event) {
        event.preventDefault();

        if (!file) {
            setError('Pilih berkas Excel (.xlsx atau .xls) terlebih dahulu.');

            return;
        }

        router.post(
            '/dashboard/posts/import',
            { file },
            {
                forceFormData: true,
                preserveScroll: true,
                onStart: () => setProcessing(true),
                onError: (errors) => setError(errors.file ?? 'Berkas tidak dapat diimpor.'),
                onSuccess: onClose,
                onFinish: () => setProcessing(false),
            },
        );
    }

    return (
        <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 p-4"
            onMouseDown={(event) => {
                if (event.target === event.currentTarget && !processing) {
                    onClose();
                }
            }}
        >
            <div
                ref={dialogRef}
                role="dialog"
                aria-modal="true"
                aria-labelledby={titleId}
                tabIndex={-1}
                className="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl focus:outline-none"
            >
                <h2 id={titleId} className="text-lg font-semibold text-slate-900">
                    Impor Artikel dari Excel
                </h2>

                <p className="mt-2 text-sm text-slate-600">
                    Baris pertama berisi nama kolom. Kolom wajib: <strong>Judul</strong>,{' '}
                    <strong>Kategori</strong>, <strong>Isi</strong>. Kolom opsional:{' '}
                    <strong>Ringkasan</strong>, <strong>Status</strong> (Terbit/Draf),{' '}
                    <strong>Tanggal Publikasi</strong>. Berkas hasil ekspor dapat langsung dipakai
                    kembali.
                </p>

                <form onSubmit={submit} noValidate className="mt-5">
                    <label htmlFor="import-file" className="mb-1 block text-sm font-medium text-slate-700">
                        Berkas Excel
                    </label>
                    <input
                        id="import-file"
                        type="file"
                        accept=".xlsx,.xls"
                        data-autofocus
                        onChange={onChange}
                        aria-invalid={Boolean(error)}
                        aria-describedby={error ? 'import-file-error' : undefined}
                        className="block w-full rounded-lg border border-slate-300 text-sm file:mr-3 file:border-0 file:bg-slate-100 file:px-3 file:py-2 file:text-sm file:font-medium"
                    />
                    {error && (
                        <p id="import-file-error" role="alert" className="mt-1 text-sm text-red-600">
                            {error}
                        </p>
                    )}

                    <div className="mt-6 flex justify-end gap-3">
                        <Button variant="secondary" onClick={onClose} disabled={processing}>
                            Batal
                        </Button>
                        <Button type="submit" loading={processing} icon={Upload}>
                            Impor
                        </Button>
                    </div>
                </form>
            </div>
        </div>
    );
}