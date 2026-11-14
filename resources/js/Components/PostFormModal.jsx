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