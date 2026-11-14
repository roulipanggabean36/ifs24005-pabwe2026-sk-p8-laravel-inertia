import { Head, useForm } from '@inertiajs/react';
import { Camera, Save } from 'lucide-react';
import { useEffect, useState } from 'react';
import Button from '../../Components/Button';
import Field, { inputClass } from '../../Components/Field';
import { PageHeader } from '../../Components/Ui';
import { initials } from '../../lib/format';
import AppLayout from '../../Layouts/AppLayout';

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_BYTES = 2 * 1024 * 1024;

export default function Edit({ profile }) {
    const { data, setData, post, processing, errors, reset, transform } = useForm({
        name: profile.name,
        username: profile.username,
        password: '',
        password_confirmation: '',
        photo: null,
        remove_photo: false,
    });
    const [previewUrl, setPreviewUrl] = useState(null);
    const [photoError, setPhotoError] = useState('');
    const [fileKey, setFileKey] = useState(0);

    useEffect(() => {
        if (!data.photo) {
            setPreviewUrl(null);

            return undefined;
        }

        const url = URL.createObjectURL(data.photo);
        setPreviewUrl(url);

        return () => URL.revokeObjectURL(url);
    }, [data.photo]);

    function onPhotoChange(event) {
        const file = event.target.files?.[0] ?? null;

        setPhotoError('');

        if (!file) {
            setData('photo', null);

            return;
        }

        if (!ALLOWED_TYPES.includes(file.type)) {
            setPhotoError('Foto profil harus berformat JPG, PNG, atau WEBP.');
            setData('photo', null);
            setFileKey((key) => key + 1);

            return;
        }

        if (file.size > MAX_BYTES) {
            setPhotoError('Ukuran foto profil maksimal 2 MB.');
            setData('photo', null);
            setFileKey((key) => key + 1);

            return;
        }

        setData((current) => ({ ...current, photo: file, remove_photo: false }));
    }

    function submit(event) {
        event.preventDefault();

        // Unggahan berkas tidak terbaca pada PUT asli, jadi gunakan POST + _method=put.
        transform((payload) => ({
            ...payload,
            _method: 'put',
            remove_photo: payload.remove_photo ? 1 : 0,
        }));

        post('/profile', {
            forceFormData: true,
            preserveScroll: true,
            onSuccess: () => {
                reset('password', 'password_confirmation', 'photo', 'remove_photo');
                setFileKey((key) => key + 1);
            },
        });
    }

    const shownPhoto = data.remove_photo ? null : (previewUrl ?? profile.photo_url);
    const photoMessage = photoError || errors.photo;

    const bind = (field, autoComplete) => ({
        id: `profile-${field.replace('_', '-')}`,
        name: field,
        autoComplete,
        value: data[field],
        onChange: (event) => setData(field, event.target.value),
        'aria-invalid': Boolean(errors[field]),
        'aria-describedby': errors[field] ? `profile-${field.replace('_', '-')}-error` : undefined,
        className: inputClass(Boolean(errors[field])),
    });

    return (
        <>
            <Head title="Profil" />

            <PageHeader title="Profil" description="Perbarui nama, username, kata sandi, dan foto profil Anda." />

            <form
                onSubmit={submit}
                noValidate
                className="max-w-2xl space-y-6 rounded-xl border border-slate-200 bg-white p-6 shadow-xs"
            >
                <section aria-labelledby="photo-title" className="flex flex-col gap-4 sm:flex-row sm:items-center">
                    {shownPhoto ? (
                        <img
                            src={shownPhoto}
                            alt="Foto profil"
                            className="h-24 w-24 rounded-full border border-slate-200 object-cover"
                        />
                    ) : (
                        <span
                            aria-hidden="true"
                            className="flex h-24 w-24 items-center justify-center rounded-full bg-indigo-600 text-2xl font-semibold text-white"
                        >
                            {initials(data.name)}
                        </span>
                    )}

                    <div className="flex-1">
                        <h2 id="photo-title" className="text-sm font-medium text-slate-700">
                            Foto profil
                        </h2>
                        <label
                            htmlFor="profile-photo"
                            className="mt-2 inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50 focus-within:ring-2 focus-within:ring-indigo-500"
                        >
                            <Camera className="h-4 w-4" aria-hidden="true" />
                            Pilih foto
                            <input
                                key={fileKey}
                                id="profile-photo"
                                name="photo"
                                type="file"
                                accept="image/jpeg,image/png,image/webp"
                                onChange={onPhotoChange}
                                aria-invalid={Boolean(photoMessage)}
                                aria-describedby={photoMessage ? 'profile-photo-error' : 'profile-photo-hint'}
                                className="sr-only"
                            />
                        </label>
                        {data.photo && (
                            <span className="ml-3 text-sm text-slate-600">{data.photo.name}</span>
                        )}

                        {photoMessage ? (
                            <p id="profile-photo-error" role="alert" className="mt-1 text-sm text-red-600">
                                {photoMessage}
                            </p>
                        ) : (
                            <p id="profile-photo-hint" className="mt-1 text-xs text-slate-500">
                                JPG, PNG, atau WEBP. Maksimal 2 MB.
                            </p>
                        )}

                        {profile.photo_url && !data.photo && (
                            <label className="mt-3 flex items-center gap-2 text-sm text-slate-700">
                                <input
                                    id="profile-remove-photo"
                                    type="checkbox"
                                    checked={data.remove_photo}
                                    onChange={(event) => setData('remove_photo', event.target.checked)}
                                    className="h-4 w-4 rounded border-slate-300 text-red-600 focus:ring-red-500"
                                />
                                Hapus foto profil
                            </label>
                        )}
                    </div>
                </section>

                <Field id="profile-name" label="Nama lengkap" error={errors.name}>
                    <input type="text" {...bind('name', 'name')} />
                </Field>

                <Field id="profile-username" label="Username" error={errors.username}>
                    <input type="text" {...bind('username', 'username')} />
                </Field>

                <fieldset className="space-y-5 rounded-lg border border-slate-200 p-4">
                    <legend className="px-1 text-sm font-medium text-slate-700">
                        Ganti kata sandi (opsional)
                    </legend>

                    <Field
                        id="profile-password"
                        label="Kata sandi baru"
                        error={errors.password}
                        hint="Kosongkan jika tidak ingin mengubah. Minimal 8 karakter."
                    >
                        <input type="password" {...bind('password', 'new-password')} />
                    </Field>

                    <Field
                        id="profile-password-confirmation"
                        label="Ulangi kata sandi baru"
                        error={errors.password_confirmation}
                    >
                        <input type="password" {...bind('password_confirmation', 'new-password')} />
                    </Field>
                </fieldset>

                <div className="flex justify-end">
                    <Button id="profile-submit" type="submit" loading={processing} icon={Save}>
                        Simpan Perubahan
                    </Button>
                </div>
            </form>
        </>
    );
}

Edit.layout = (page) => <AppLayout variant="dashboard">{page}</AppLayout>;