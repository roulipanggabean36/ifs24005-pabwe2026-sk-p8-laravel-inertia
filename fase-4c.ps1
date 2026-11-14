# fase-4c.ps1 - jalankan dari root proyek
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
foreach ($need in @(
  'resources/js/Layouts/AppLayout.jsx',
  'resources/js/Components/Modal.jsx',
  'resources/js/Components/KebabMenu.jsx',
  'resources/js/Components/ConfirmDialog.jsx',
  'resources/js/Components/Pagination.jsx',
  'resources/js/Components/MarkdownEditor.jsx',
  'resources/js/Components/MarkdownViewer.jsx',
  'resources/js/Components/Ui.jsx',
  'resources/js/lib/http.js',
  'resources/js/Pages/Auth/Login.jsx'
)) {
  if (-not (Test-Path $need)) {
    Write-Host "GAGAL: $need belum ada. Jalankan fase-4a.ps1 dan fase-4b.ps1 dulu." -ForegroundColor Red
    exit 1
  }
}

# ---------------------------------------------------------------
# 1. Components/CoverUploader
# ---------------------------------------------------------------
W 'resources/js/Components/CoverUploader.jsx' @'
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
'@

# ---------------------------------------------------------------
# 2. Components/PostFormModal (Tambah + Ubah)
# ---------------------------------------------------------------
W 'resources/js/Components/PostFormModal.jsx' @'
import { useForm } from '@inertiajs/react';
import { ImagePlus, Save } from 'lucide-react';
import { useEffect, useState } from 'react';
import Button from './Button';
import CoverUploader from './CoverUploader';
import Field, { inputClass } from './Field';
import MarkdownEditor from './MarkdownEditor';
import Modal from './Modal';

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_BYTES = 2 * 1024 * 1024;

/**
 * Modal Full Screen untuk Tambah (mode="create") dan Ubah (mode="edit").
 * Dipasang hanya saat terbuka, sehingga state form selalu segar.
 */
export default function PostFormModal({ mode, article = null, categories, onClose }) {
    const isEdit = mode === 'edit';

    const { data, setData, processing, errors, transform, post, put } = useForm({
        title: article?.title ?? '',
        category: article?.category ?? categories[0]?.value ?? 'Umum',
        excerpt: article?.excerpt ?? '',
        content: article?.content ?? '',
        is_published: article?.is_published ?? false,
        cover: null,
    });

    const [coverPreview, setCoverPreview] = useState(null);
    const [coverError, setCoverError] = useState('');
    const [fileKey, setFileKey] = useState(0);

    useEffect(() => {
        if (!data.cover) {
            setCoverPreview(null);

            return undefined;
        }

        const url = URL.createObjectURL(data.cover);
        setCoverPreview(url);

        return () => URL.revokeObjectURL(url);
    }, [data.cover]);

    function onCoverChange(event) {
        const file = event.target.files?.[0] ?? null;

        setCoverError('');

        if (!file) {
            setData('cover', null);

            return;
        }

        if (!ALLOWED_TYPES.includes(file.type)) {
            setCoverError('Foto sampul harus berformat JPG, PNG, atau WEBP.');
            setData('cover', null);
            setFileKey((key) => key + 1);

            return;
        }

        if (file.size > MAX_BYTES) {
            setCoverError('Ukuran foto sampul maksimal 2 MB.');
            setData('cover', null);
            setFileKey((key) => key + 1);

            return;
        }

        setData('cover', file);
    }

    function submit(event) {
        event.preventDefault();

        if (isEdit) {
            transform((payload) => {
                const { cover, ...rest } = payload;

                return rest;
            });

            put(`/dashboard/posts/${article.id}`, {
                preserveScroll: true,
                onSuccess: onClose,
            });

            return;
        }

        transform((payload) => {
            const result = { ...payload, is_published: payload.is_published ? 1 : 0 };

            if (!result.cover) {
                delete result.cover;
            }

            return result;
        });

        post('/dashboard/posts', {
            forceFormData: true,
            preserveScroll: true,
            onSuccess: onClose,
        });
    }

    const describe = (field) => (errors[field] ? `post-${field}-error` : undefined);

    return (
        <Modal
            open
            title={isEdit ? 'Ubah Artikel' : 'Tambah Artikel'}
            tone={isEdit ? 'edit' : 'create'}
            onClose={onClose}
            footer={
                <>
                    <Button variant="secondary" onClick={onClose} disabled={processing}>
                        Batal
                    </Button>
                    <Button
                        id="post-submit"
                        type="submit"
                        form="post-form"
                        variant={isEdit ? 'warning' : 'primary'}
                        loading={processing}
                        icon={Save}
                    >
                        Simpan
                    </Button>
                </>
            }
        >
            <form id="post-form" onSubmit={submit} noValidate className="space-y-6">
                <Field id="post-title" label="Judul" error={errors.title}>
                    <input
                        id="post-title"
                        name="title"
                        type="text"
                        data-autofocus
                        value={data.title}
                        onChange={(event) => setData('title', event.target.value)}
                        aria-invalid={Boolean(errors.title)}
                        aria-describedby={describe('title')}
                        className={inputClass(Boolean(errors.title))}
                    />
                </Field>

                <div className="grid gap-6 sm:grid-cols-2">
                    <Field id="post-category" label="Kategori" error={errors.category}>
                        <select
                            id="post-category"
                            name="category"
                            value={data.category}
                            onChange={(event) => setData('category', event.target.value)}
                            aria-invalid={Boolean(errors.category)}
                            aria-describedby={describe('category')}
                            className={inputClass(Boolean(errors.category))}
                        >
                            {categories.map((category) => (
                                <option key={category.value} value={category.value}>
                                    {category.label}
                                </option>
                            ))}
                        </select>
                    </Field>

                    <div className="flex items-end">
                        <label
                            htmlFor="post-published"
                            className="flex items-center gap-2 text-sm text-slate-700"
                        >
                            <input
                                id="post-published"
                                type="checkbox"
                                checked={data.is_published}
                                onChange={(event) => setData('is_published', event.target.checked)}
                                className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                            />
                            Publikasikan artikel (tampil di halaman publik)
                        </label>
                    </div>
                </div>

                <Field
                    id="post-excerpt"
                    label="Ringkasan"
                    error={errors.excerpt}
                    hint="Kosongkan untuk dibuat otomatis dari isi artikel."
                >
                    <textarea
                        id="post-excerpt"
                        name="excerpt"
                        rows={3}
                        value={data.excerpt}
                        onChange={(event) => setData('excerpt', event.target.value)}
                        aria-invalid={Boolean(errors.excerpt)}
                        aria-describedby={describe('excerpt') ?? 'post-excerpt-hint'}
                        className={inputClass(Boolean(errors.excerpt))}
                    />
                </Field>

                <div>
                    <p id="post-content-label" className="mb-1 text-sm font-medium text-slate-700">
                        Isi artikel (Markdown)
                    </p>
                    <MarkdownEditor
                        label="Isi artikel (Markdown)"
                        value={data.content}
                        onChange={(value) => setData('content', value)}
                    />
                    {errors.content && (
                        <p id="post-content-error" role="alert" className="mt-1 text-sm text-red-600">
                            {errors.content}
                        </p>
                    )}
                </div>

                {isEdit ? (
                    <CoverUploader post={article} />
                ) : (
                    <div className="rounded-lg border border-slate-200 p-4">
                        <h3 className="text-sm font-medium text-slate-700">Foto sampul (opsional)</h3>

                        {coverPreview && (
                            <img
                                src={coverPreview}
                                alt="Pratinjau foto sampul"
                                className="mt-3 aspect-video w-full max-w-md rounded-lg border border-slate-200 object-cover"
                            />
                        )}

                        <label
                            htmlFor="post-cover"
                            className="mt-3 inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50 focus-within:ring-2 focus-within:ring-indigo-500"
                        >
                            <ImagePlus className="h-4 w-4" aria-hidden="true" />
                            {data.cover ? 'Ganti foto' : 'Pilih foto'}
                            <input
                                key={fileKey}
                                id="post-cover"
                                name="cover"
                                type="file"
                                accept="image/jpeg,image/png,image/webp"
                                onChange={onCoverChange}
                                aria-describedby={coverError || errors.cover ? 'post-cover-error' : undefined}
                                className="sr-only"
                            />
                        </label>
                        {data.cover && (
                            <span className="ml-3 text-sm text-slate-600">{data.cover.name}</span>
                        )}

                        {coverError || errors.cover ? (
                            <p id="post-cover-error" role="alert" className="mt-2 text-sm text-red-600">
                                {coverError || errors.cover}
                            </p>
                        ) : (
                            <p className="mt-2 text-xs text-slate-500">
                                JPG, PNG, atau WEBP. Maksimal 2 MB.
                            </p>
                        )}
                    </div>
                )}
            </form>
        </Modal>
    );
}
'@

# ---------------------------------------------------------------
# 3. Components/AiGeneratorModal
# ---------------------------------------------------------------
W 'resources/js/Components/AiGeneratorModal.jsx' @'
import { router } from '@inertiajs/react';
import { Save, Sparkles } from 'lucide-react';
import { useState } from 'react';
import { errorMessage, postJson } from '../lib/http';
import Button from './Button';
import Field, { inputClass } from './Field';
import Modal from './Modal';
import { CategoryBadge } from './Ui';

/**
 * Generator artikel via OpenAI: hasilkan dulu (tidak disimpan), pilih, lalu simpan sebagai draf.
 */
export default function AiGeneratorModal({ max, onClose }) {
    const [topic, setTopic] = useState('');
    const [count, setCount] = useState('3');
    const [fieldErrors, setFieldErrors] = useState({});
    const [message, setMessage] = useState('');
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [items, setItems] = useState([]);
    const [selected, setSelected] = useState([]);

    const selectedCount = selected.filter(Boolean).length;

    async function generate(event) {
        event.preventDefault();
        setMessage('');

        const next = {};
        const amount = Number(count);

        if (topic.trim() === '') {
            next.topic = 'Topik wajib diisi.';
        }

        if (count === '' || !Number.isInteger(amount) || amount < 1 || amount > max) {
            next.count = `Jumlah harus bilangan bulat antara 1 dan ${max}.`;
        }

        setFieldErrors(next);

        if (Object.keys(next).length > 0) {
            return;
        }

        setLoading(true);

        const result = await postJson('/dashboard/posts/ai-generate', {
            topic: topic.trim(),
            count: amount,
        });

        setLoading(false);

        if (!result.ok) {
            setMessage(errorMessage(result));

            return;
        }

        const list = Array.isArray(result.data.items) ? result.data.items : [];

        setItems(list);
        setSelected(list.map(() => true));
    }

    function toggle(index) {
        setSelected((current) => current.map((value, i) => (i === index ? !value : value)));
    }

    function save() {
        const chosen = items.filter((_, index) => selected[index]);

        if (chosen.length === 0) {
            setMessage('Pilih minimal satu artikel untuk disimpan.');

            return;
        }

        setMessage('');

        router.post(
            '/dashboard/posts/ai-save',
            { items: chosen },
            {
                preserveScroll: true,
                onStart: () => setSaving(true),
                onError: (errors) =>
                    setMessage(Object.values(errors)[0] ?? 'Artikel gagal disimpan. Silakan coba lagi.'),
                onSuccess: onClose,
                onFinish: () => setSaving(false),
            },
        );
    }

    return (
        <Modal
            open
            title="Generator Artikel AI"
            tone="ai"
            onClose={onClose}
            footer={
                <>
                    <Button variant="secondary" onClick={onClose} disabled={loading || saving}>
                        Batal
                    </Button>
                    <Button
                        id="ai-generate"
                        type="submit"
                        form="ai-form"
                        variant={items.length > 0 ? 'secondary' : 'violet'}
                        loading={loading}
                        disabled={saving}
                        icon={Sparkles}
                    >
                        {items.length > 0 ? 'Hasilkan Ulang' : 'Hasilkan Artikel'}
                    </Button>
                    {items.length > 0 && (
                        <Button
                            id="ai-save"
                            variant="violet"
                            icon={Save}
                            loading={saving}
                            disabled={loading}
                            onClick={save}
                        >
                            Simpan {selectedCount} Artikel sebagai Draf
                        </Button>
                    )}
                </>
            }
        >
            <form id="ai-form" onSubmit={generate} noValidate className="grid gap-6 sm:grid-cols-3">
                <div className="sm:col-span-2">
                    <Field id="ai-topic" label="Topik artikel" error={fieldErrors.topic}>
                        <input
                            id="ai-topic"
                            type="text"
                            data-autofocus
                            maxLength={200}
                            value={topic}
                            onChange={(event) => setTopic(event.target.value)}
                            placeholder="Contoh: produktivitas belajar untuk mahasiswa"
                            aria-invalid={Boolean(fieldErrors.topic)}
                            aria-describedby={fieldErrors.topic ? 'ai-topic-error' : undefined}
                            className={inputClass(Boolean(fieldErrors.topic))}
                        />
                    </Field>
                </div>

                <Field
                    id="ai-count"
                    label="Jumlah artikel"
                    error={fieldErrors.count}
                    hint={`Antara 1 dan ${max}.`}
                >
                    <input
                        id="ai-count"
                        type="number"
                        inputMode="numeric"
                        min={1}
                        max={max}
                        step={1}
                        value={count}
                        onChange={(event) => setCount(event.target.value)}
                        aria-invalid={Boolean(fieldErrors.count)}
                        aria-describedby={fieldErrors.count ? 'ai-count-error' : 'ai-count-hint'}
                        className={inputClass(Boolean(fieldErrors.count))}
                    />
                </Field>
            </form>

            {message && (
                <p
                    role="alert"
                    className="mt-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
                >
                    {message}
                </p>
            )}

            {loading && (
                <p role="status" className="mt-6 text-sm text-slate-600">
                    AI sedang menulis artikel, mohon tunggu sebentar...
                </p>
            )}

            {items.length > 0 && (
                <section className="mt-8" aria-labelledby="ai-result-title">
                    <h3 id="ai-result-title" className="text-lg font-semibold text-slate-900">
                        Hasil ({items.length} artikel)
                    </h3>
                    <p className="mt-1 text-sm text-slate-600">
                        Hasil belum disimpan. Pilih artikel yang ingin disimpan sebagai draf.
                    </p>

                    <ul className="mt-4 space-y-4">
                        {items.map((item, index) => (
                            <li
                                key={`${index}-${item.title}`}
                                className="rounded-xl border border-slate-200 bg-white p-4"
                            >
                                <label
                                    htmlFor={`ai-item-${index}`}
                                    className="flex items-start gap-3"
                                >
                                    <input
                                        id={`ai-item-${index}`}
                                        type="checkbox"
                                        checked={Boolean(selected[index])}
                                        onChange={() => toggle(index)}
                                        className="mt-1 h-4 w-4 rounded border-slate-300 text-violet-600 focus:ring-violet-500"
                                    />
                                    <span className="min-w-0 flex-1">
                                        <span className="block font-medium text-slate-900">
                                            {item.title}
                                        </span>
                                        <span className="mt-1 block">
                                            <CategoryBadge category={item.category} />
                                        </span>
                                        {item.excerpt && (
                                            <span className="mt-2 block text-sm text-slate-600">
                                                {item.excerpt}
                                            </span>
                                        )}
                                    </span>
                                </label>

                                <details className="mt-3 pl-7">
                                    <summary className="text-sm font-medium text-violet-700">
                                        Lihat isi artikel
                                    </summary>
                                    <pre className="mt-2 max-h-64 overflow-y-auto whitespace-pre-wrap rounded-lg bg-slate-50 p-3 text-xs text-slate-700">
                                        {item.content}
                                    </pre>
                                </details>
                            </li>
                        ))}
                    </ul>
                </section>
            )}
        </Modal>
    );
}
'@

# ---------------------------------------------------------------
# 4. Components/ImportModal
# ---------------------------------------------------------------
W 'resources/js/Components/ImportModal.jsx' @'
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
'@

# ---------------------------------------------------------------
# 5. Pages/Post/Index
# ---------------------------------------------------------------
W 'resources/js/Pages/Post/Index.jsx' @'
import { Head, Link, router, usePage } from '@inertiajs/react';
import {
    CircleCheck,
    Clock,
    Download,
    Eye,
    EyeOff,
    FileText,
    Globe,
    Pencil,
    Plus,
    Search,
    Sparkles,
    Trash2,
    Upload,
    X,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import AiGeneratorModal from '../../Components/AiGeneratorModal';
import Button, { buttonClasses } from '../../Components/Button';
import ConfirmDialog from '../../Components/ConfirmDialog';
import { inputClass } from '../../Components/Field';
import ImportModal from '../../Components/ImportModal';
import KebabMenu from '../../Components/KebabMenu';
import Pagination from '../../Components/Pagination';
import PostFormModal from '../../Components/PostFormModal';
import { CategoryBadge, PageHeader, StatCard, StatusBadge } from '../../Components/Ui';
import { formatDate } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

function PostRow({ post, toggling, onToggle, onEdit, onDelete }) {
    const items = [
        {
            label: 'Detail',
            icon: Eye,
            tone: 'primary',
            onClick: () => router.visit(`/dashboard/posts/${post.id}`),
        },
        { label: 'Ubah', icon: Pencil, tone: 'primary', onClick: onEdit },
        { label: 'Hapus', icon: Trash2, tone: 'danger', onClick: onDelete },
    ];

    return (
        <li className="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center sm:gap-4">
            <div className="flex min-w-0 flex-1 items-center gap-4">
                {post.cover_url ? (
                    <img
                        src={post.cover_url}
                        alt=""
                        loading="lazy"
                        className="hidden h-12 w-20 shrink-0 rounded-md object-cover sm:block"
                    />
                ) : (
                    <span
                        aria-hidden="true"
                        className="hidden h-12 w-20 shrink-0 items-center justify-center rounded-md bg-slate-100 text-slate-400 sm:flex"
                    >
                        <FileText className="h-5 w-5" />
                    </span>
                )}

                <div className="min-w-0">
                    <Link
                        href={`/dashboard/posts/${post.id}`}
                        className="block truncate font-medium text-slate-900 hover:text-indigo-700"
                    >
                        {post.title}
                    </Link>
                    <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-slate-500">
                        <CategoryBadge category={post.category} />
                        <StatusBadge published={post.is_published} />
                        <span>
                            {post.is_published
                                ? `Terbit ${formatDate(post.published_at)}`
                                : `Dibuat ${formatDate(post.created_at)}`}
                        </span>
                    </div>
                </div>
            </div>

            <div className="flex items-center gap-2 self-end sm:self-auto">
                <Button
                    variant={post.is_published ? 'secondary' : 'success'}
                    size="sm"
                    icon={post.is_published ? EyeOff : Globe}
                    loading={toggling}
                    onClick={onToggle}
                >
                    {post.is_published ? 'Jadikan Draf' : 'Publikasikan'}
                </Button>
                <KebabMenu items={items} label={`Menu tindakan untuk ${post.title}`} />
            </div>
        </li>
    );
}

export default function Index({ posts, stats, filters, categories, aiMax }) {
    const { flash } = usePage().props;
    const importErrors = flash?.import_errors ?? [];

    const [search, setSearch] = useState(filters.search ?? '');
    const [createOpen, setCreateOpen] = useState(false);
    const [editId, setEditId] = useState(null);
    const [aiOpen, setAiOpen] = useState(false);
    const [importOpen, setImportOpen] = useState(false);
    const [deleteTarget, setDeleteTarget] = useState(null);
    const [deleting, setDeleting] = useState(false);
    const [togglingId, setTogglingId] = useState(null);
    const [showImportErrors, setShowImportErrors] = useState(importErrors.length > 0);

    useEffect(() => {
        setSearch(filters.search ?? '');
    }, [filters.search]);

    useEffect(() => {
        setShowImportErrors(importErrors.length > 0);
    }, [importErrors.length]);

    const editing = editId === null ? null : (posts.data.find((item) => item.id === editId) ?? null);

    function visit(next) {
        const merged = { ...filters, ...next };
        const query = {};

        ['search', 'category', 'status'].forEach((key) => {
            if (merged[key]) {
                query[key] = merged[key];
            }
        });

        router.get('/dashboard/posts', query, { preserveScroll: true, preserveState: true });
    }

    function submitSearch(event) {
        event.preventDefault();
        visit({ search: search.trim() });
    }

    function togglePublish(post) {
        router.patch(
            `/dashboard/posts/${post.id}/publish`,
            {},
            {
                preserveScroll: true,
                onStart: () => setTogglingId(post.id),
                onFinish: () => setTogglingId(null),
            },
        );
    }

    function confirmDelete() {
        router.delete(`/dashboard/posts/${deleteTarget.id}`, {
            preserveScroll: true,
            onStart: () => setDeleting(true),
            onFinish: () => {
                setDeleting(false);
                setDeleteTarget(null);
            },
        });
    }

    const hasFilter = Boolean(filters.search || filters.category || filters.status);

    return (
        <>
            <Head title="Artikel Saya" />

            <PageHeader
                title="Artikel Saya"
                description="Kelola artikel yang Anda tulis: buat, ubah, terbitkan, impor, dan ekspor."
                actions={
                    <>
                        <Button
                            id="btn-create-post"
                            icon={Plus}
                            onClick={() => setCreateOpen(true)}
                        >
                            Tambah Artikel
                        </Button>
                        <Button
                            id="btn-ai-generate"
                            variant="violet"
                            icon={Sparkles}
                            onClick={() => setAiOpen(true)}
                        >
                            Generate AI
                        </Button>
                        <Button
                            id="btn-import-posts"
                            variant="secondary"
                            icon={Upload}
                            onClick={() => setImportOpen(true)}
                        >
                            Impor Excel
                        </Button>
                        <a
                            id="btn-export-posts"
                            href="/dashboard/posts/export"
                            className={buttonClasses('secondary', 'md')}
                        >
                            <Download className="h-4 w-4" aria-hidden="true" />
                            Ekspor Excel
                        </a>
                    </>
                }
            />

            <section aria-label="Ringkasan statistik artikel" className="grid gap-4 sm:grid-cols-3">
                <StatCard
                    label="Total Artikel"
                    value={stats.total}
                    icon={FileText}
                    tone="indigo"
                    active={!filters.status}
                    onClick={() => visit({ status: '' })}
                />
                <StatCard
                    label="Total Selesai"
                    value={stats.published}
                    icon={CircleCheck}
                    tone="emerald"
                    active={filters.status === 'published'}
                    onClick={() => visit({ status: 'published' })}
                />
                <StatCard
                    label="Belum Selesai"
                    value={stats.draft}
                    icon={Clock}
                    tone="amber"
                    active={filters.status === 'draft'}
                    onClick={() => visit({ status: 'draft' })}
                />
            </section>

            {showImportErrors && importErrors.length > 0 && (
                <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 p-4">
                    <div className="flex items-start justify-between gap-3">
                        <p className="font-medium text-red-800">
                            {importErrors.length} baris gagal diimpor
                        </p>
                        <button
                            type="button"
                            onClick={() => setShowImportErrors(false)}
                            aria-label="Tutup laporan impor"
                            className="rounded p-0.5 text-red-700 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-500"
                        >
                            <X className="h-4 w-4" aria-hidden="true" />
                        </button>
                    </div>
                    <ul className="mt-2 max-h-48 space-y-1 overflow-y-auto text-sm text-red-700">
                        {importErrors.map((item, index) => (
                            <li key={`${item.row}-${index}`}>
                                Baris {item.row}: {item.message}
                            </li>
                        ))}
                    </ul>
                </div>
            )}

            <section className="mt-6" aria-label="Daftar artikel">
                <form
                    onSubmit={submitSearch}
                    role="search"
                    className="flex flex-col gap-3 sm:flex-row"
                >
                    <div className="relative flex-1">
                        <label htmlFor="filter-search" className="sr-only">
                            Cari artikel berdasarkan judul atau isi
                        </label>
                        <Search
                            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                            aria-hidden="true"
                        />
                        <input
                            id="filter-search"
                            type="search"
                            value={search}
                            onChange={(event) => setSearch(event.target.value)}
                            placeholder="Cari judul atau isi artikel..."
                            className={`${inputClass(false)} pl-9`}
                        />
                    </div>

                    <div>
                        <label htmlFor="filter-category" className="sr-only">
                            Filter kategori
                        </label>
                        <select
                            id="filter-category"
                            value={filters.category ?? ''}
                            onChange={(event) => visit({ category: event.target.value })}
                            className={inputClass(false)}
                        >
                            <option value="">Semua kategori</option>
                            {categories.map((category) => (
                                <option key={category.value} value={category.value}>
                                    {category.label}
                                </option>
                            ))}
                        </select>
                    </div>

                    <Button type="submit" icon={Search}>
                        Cari
                    </Button>
                </form>

                <p className="mt-4 text-sm text-slate-600" aria-live="polite">
                    {posts.total} artikel ditemukan
                    {hasFilter && (
                        <>
                            {' '}
                            &middot;{' '}
                            <Link
                                href="/dashboard/posts"
                                className="font-medium text-indigo-700 hover:underline"
                            >
                                Hapus filter
                            </Link>
                        </>
                    )}
                </p>

                {posts.data.length === 0 ? (
                    <div className="mt-4 rounded-xl border border-dashed border-slate-300 bg-white p-12 text-center">
                        <FileText className="mx-auto h-10 w-10 text-slate-400" aria-hidden="true" />
                        <p className="mt-3 font-medium text-slate-900">
                            {hasFilter ? 'Tidak ada artikel yang cocok' : 'Belum ada artikel'}
                        </p>
                        <p className="mt-1 text-sm text-slate-600">
                            {hasFilter
                                ? 'Coba ubah kata kunci atau filter Anda.'
                                : 'Mulai menulis artikel pertama Anda sekarang.'}
                        </p>
                        {!hasFilter && (
                            <div className="mt-4">
                                <Button icon={Plus} onClick={() => setCreateOpen(true)}>
                                    Tambah Artikel
                                </Button>
                            </div>
                        )}
                    </div>
                ) : (
                    <div className="mt-4 rounded-xl border border-slate-200 bg-white shadow-xs">
                        <ul className="divide-y divide-slate-100">
                            {posts.data.map((post) => (
                                <PostRow
                                    key={post.id}
                                    post={post}
                                    toggling={togglingId === post.id}
                                    onToggle={() => togglePublish(post)}
                                    onEdit={() => setEditId(post.id)}
                                    onDelete={() => setDeleteTarget(post)}
                                />
                            ))}
                        </ul>
                    </div>
                )}

                <Pagination paginator={posts} />
            </section>

            {createOpen && (
                <PostFormModal
                    mode="create"
                    categories={categories}
                    onClose={() => setCreateOpen(false)}
                />
            )}

            {editing && (
                <PostFormModal
                    key={editing.id}
                    mode="edit"
                    article={editing}
                    categories={categories}
                    onClose={() => setEditId(null)}
                />
            )}

            {aiOpen && <AiGeneratorModal max={aiMax} onClose={() => setAiOpen(false)} />}

            {importOpen && <ImportModal onClose={() => setImportOpen(false)} />}

            <ConfirmDialog
                open={deleteTarget !== null}
                title="Hapus artikel?"
                message={`Artikel "${deleteTarget?.title ?? ''}" akan dihapus permanen beserta foto sampulnya.`}
                loading={deleting}
                onConfirm={confirmDelete}
                onCancel={() => setDeleteTarget(null)}
            />
        </>
    );
}

Index.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 6. Pages/Post/Show
# ---------------------------------------------------------------
W 'resources/js/Pages/Post/Show.jsx' @'
import { Head, Link, router } from '@inertiajs/react';
import { ArrowLeft, Calendar, EyeOff, ExternalLink, Globe, Pencil, Trash2 } from 'lucide-react';
import { useState } from 'react';
import Button, { buttonClasses } from '../../Components/Button';
import ConfirmDialog from '../../Components/ConfirmDialog';
import CoverUploader from '../../Components/CoverUploader';
import MarkdownViewer from '../../Components/MarkdownViewer';
import PostFormModal from '../../Components/PostFormModal';
import { CategoryBadge, StatusBadge } from '../../Components/Ui';
import { formatDate } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

export default function Show({ post, categories }) {
    const [editOpen, setEditOpen] = useState(false);
    const [deleteOpen, setDeleteOpen] = useState(false);
    const [deleting, setDeleting] = useState(false);
    const [toggling, setToggling] = useState(false);

    function togglePublish() {
        router.patch(
            `/dashboard/posts/${post.id}/publish`,
            {},
            {
                preserveScroll: true,
                onStart: () => setToggling(true),
                onFinish: () => setToggling(false),
            },
        );
    }

    function destroy() {
        router.delete(`/dashboard/posts/${post.id}`, {
            onStart: () => setDeleting(true),
            onFinish: () => {
                setDeleting(false);
                setDeleteOpen(false);
            },
        });
    }

    return (
        <>
            <Head title={post.title} />

            <Link
                href="/dashboard/posts"
                className="inline-flex items-center gap-1 text-sm font-medium text-indigo-700 hover:underline"
            >
                <ArrowLeft className="h-4 w-4" aria-hidden="true" />
                Kembali ke daftar artikel
            </Link>

            <header className="mt-4 rounded-xl border border-slate-200 bg-white p-6 shadow-xs">
                <div className="flex flex-wrap items-center gap-2">
                    <CategoryBadge category={post.category} />
                    <StatusBadge published={post.is_published} />
                </div>

                <h1 className="mt-3 text-2xl font-bold text-slate-900 sm:text-3xl">{post.title}</h1>

                {post.excerpt && <p className="mt-3 text-slate-600">{post.excerpt}</p>}

                <dl className="mt-4 flex flex-wrap gap-x-6 gap-y-1 text-sm text-slate-500">
                    <div className="inline-flex items-center gap-1.5">
                        <Calendar className="h-4 w-4" aria-hidden="true" />
                        <dt className="sr-only">Dibuat</dt>
                        <dd>Dibuat {formatDate(post.created_at)}</dd>
                    </div>
                    <div>
                        <dt className="sr-only">Diperbarui</dt>
                        <dd>Diperbarui {formatDate(post.updated_at)}</dd>
                    </div>
                    {post.is_published && post.published_at && (
                        <div>
                            <dt className="sr-only">Dipublikasikan</dt>
                            <dd>Terbit {formatDate(post.published_at)}</dd>
                        </div>
                    )}
                </dl>

                <div className="mt-5 flex flex-wrap items-center gap-2">
                    <Button
                        id="btn-edit-post"
                        variant="warning"
                        icon={Pencil}
                        onClick={() => setEditOpen(true)}
                    >
                        Ubah
                    </Button>
                    <Button
                        variant={post.is_published ? 'secondary' : 'success'}
                        icon={post.is_published ? EyeOff : Globe}
                        loading={toggling}
                        onClick={togglePublish}
                    >
                        {post.is_published ? 'Jadikan Draf' : 'Publikasikan'}
                    </Button>
                    {post.is_published && (
                        <a
                            href={`/articles/${post.slug}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className={buttonClasses('secondary', 'md')}
                        >
                            <ExternalLink className="h-4 w-4" aria-hidden="true" />
                            Lihat di halaman publik
                        </a>
                    )}
                    <Button variant="danger" icon={Trash2} onClick={() => setDeleteOpen(true)}>
                        Hapus
                    </Button>
                </div>
            </header>

            <div className="mt-6">
                <CoverUploader post={post} />
            </div>

            <section
                aria-label="Isi artikel"
                className="mt-6 rounded-xl border border-slate-200 bg-white p-5 shadow-xs sm:p-8"
            >
                <MarkdownViewer content={post.content} />
            </section>

            {editOpen && (
                <PostFormModal
                    mode="edit"
                    article={post}
                    categories={categories}
                    onClose={() => setEditOpen(false)}
                />
            )}

            <ConfirmDialog
                open={deleteOpen}
                title="Hapus artikel?"
                message={`Artikel "${post.title}" akan dihapus permanen beserta foto sampulnya.`}
                loading={deleting}
                onConfirm={destroy}
                onCancel={() => setDeleteOpen(false)}
            />
        </>
    );
}

Show.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;
'@

# ---------------------------------------------------------------
# 7. Cek bundle (sintaks + import) untuk seluruh file JS selain app.jsx
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

# ---------------------------------------------------------------
# 8. Build Vite penuh
# ---------------------------------------------------------------
Write-Host ">> npm run build" -ForegroundColor Cyan
npm run build
if ($LASTEXITCODE -ne 0) {
  Write-Host "GAGAL: npm run build (exit code $LASTEXITCODE)" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "FASE 4c SELESAI." -ForegroundColor Green