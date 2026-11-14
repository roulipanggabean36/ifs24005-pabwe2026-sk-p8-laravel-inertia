import { router } from '@inertiajs/react';
import { ImagePlus, Trash2 } from 'lucide-react';
import { useState } from 'react';
import Button from './Button';
import Spinner from './Spinner';

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_BYTES = 2 * 1024 * 1024;

/**
 * Kelola foto sampul artikel yang sudah tersimpan: unggah/ganti dan hapus.
 */
export default function CoverUploader({ post }) {
    const [error, setError] = useState('');
    const [uploading, setUploading] = useState(false);
    const [removing, setRemoving] = useState(false);
    const [confirming, setConfirming] = useState(false);
    const [fileKey, setFileKey] = useState(0);

    const inputId = `cover-input-${post.id}`;
    const busy = uploading || removing;

    function onChange(event) {
        const file = event.target.files?.[0];

        setError('');

        if (!file) {
            return;
        }

        if (!ALLOWED_TYPES.includes(file.type)) {
            setError('Foto sampul harus berformat JPG, PNG, atau WEBP.');
            setFileKey((key) => key + 1);

            return;
        }

        if (file.size > MAX_BYTES) {
            setError('Ukuran foto sampul maksimal 2 MB.');
            setFileKey((key) => key + 1);

            return;
        }

        router.post(
            `/dashboard/posts/${post.id}/cover`,
            { cover: file },
            {
                forceFormData: true,
                preserveScroll: true,
                onStart: () => setUploading(true),
                onError: (errors) => setError(errors.cover ?? 'Foto sampul gagal diunggah.'),
                onFinish: () => {
                    setUploading(false);
                    setFileKey((key) => key + 1);
                },
            },
        );
    }

    function remove() {
        router.delete(`/dashboard/posts/${post.id}/cover`, {
            preserveScroll: true,
            onStart: () => setRemoving(true),
            onFinish: () => {
                setRemoving(false);
                setConfirming(false);
            },
        });
    }

    return (
        <div className="rounded-lg border border-slate-200 p-4">
            <h3 className="text-sm font-medium text-slate-700">Foto sampul</h3>

            {post.cover_url ? (
                <img
                    src={post.cover_url}
                    alt="Foto sampul artikel"
                    className="mt-3 aspect-video w-full max-w-md rounded-lg border border-slate-200 object-cover"
                />
            ) : (
                <div className="mt-3 flex aspect-video w-full max-w-md items-center justify-center rounded-lg border border-dashed border-slate-300 bg-slate-50 text-sm text-slate-500">
                    Belum ada foto sampul
                </div>
            )}

            <div className="mt-3 flex flex-wrap items-center gap-2">
                <label
                    htmlFor={inputId}
                    className={`inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50 focus-within:ring-2 focus-within:ring-indigo-500 ${
                        busy ? 'pointer-events-none opacity-60' : ''
                    }`}
                >
                    {uploading ? (
                        <Spinner />
                    ) : (
                        <ImagePlus className="h-4 w-4" aria-hidden="true" />
                    )}
                    {post.cover_url ? 'Ganti foto' : 'Unggah foto'}
                    <input
                        key={fileKey}
                        id={inputId}
                        type="file"
                        accept="image/jpeg,image/png,image/webp"
                        disabled={busy}
                        onChange={onChange}
                        aria-describedby={error ? `${inputId}-error` : undefined}
                        className="sr-only"
                    />
                </label>

                {post.cover_url && !confirming && (
                    <Button
                        variant="secondary"
                        size="sm"
                        icon={Trash2}
                        disabled={busy}
                        onClick={() => setConfirming(true)}
                    >
                        Hapus sampul
                    </Button>
                )}

                {confirming && (
                    <>
                        <span className="text-sm text-red-700">Hapus foto sampul ini?</span>
                        <Button variant="danger" size="sm" loading={removing} onClick={remove}>
                            Ya, hapus
                        </Button>
                        <Button
                            variant="secondary"
                            size="sm"
                            disabled={removing}
                            onClick={() => setConfirming(false)}
                        >
                            Batal
                        </Button>
                    </>
                )}
            </div>

            {error ? (
                <p id={`${inputId}-error`} role="alert" className="mt-2 text-sm text-red-600">
                    {error}
                </p>
            ) : (
                <p className="mt-2 text-xs text-slate-500">JPG, PNG, atau WEBP. Maksimal 2 MB.</p>
            )}
        </div>
    );
}