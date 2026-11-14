import { Head, Link, useForm } from '@inertiajs/react';
import { UserPlus } from 'lucide-react';
import Button from '../../Components/Button';
import Field, { inputClass } from '../../Components/Field';
import AppLayout from '../../Layouts/AppLayout';

export default function Register() {
    const { data, setData, post, processing, errors, reset } = useForm({
        name: '',
        username: '',
        password: '',
        password_confirmation: '',
    });

    function submit(event) {
        event.preventDefault();
        post('/register', {
            onFinish: () => reset('password', 'password_confirmation'),
        });
    }

    const bind = (field, autoComplete) => ({
        id: `register-${field.replace('_', '-')}`,
        name: field,
        autoComplete,
        value: data[field],
        onChange: (event) => setData(field, event.target.value),
        'aria-invalid': Boolean(errors[field]),
        'aria-describedby': errors[field] ? `register-${field.replace('_', '-')}-error` : undefined,
        className: inputClass(Boolean(errors[field])),
    });

    return (
        <>
            <Head title="Daftar" />

            <div className="mx-auto flex max-w-md flex-col px-4 py-12 sm:py-16">
                <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
                    <h1 className="text-2xl font-bold text-slate-900">Daftar Penulis</h1>
                    <p className="mt-1 text-sm text-slate-600">
                        Buat akun untuk mulai menulis dan menerbitkan artikel Anda.
                    </p>

                    <form onSubmit={submit} noValidate className="mt-6 space-y-5">
                        <Field id="register-name" label="Nama lengkap" error={errors.name}>
                            <input type="text" {...bind('name', 'name')} />
                        </Field>

                        <Field
                            id="register-username"
                            label="Username"
                            error={errors.username}
                            hint="Huruf, angka, strip, dan garis bawah. Minimal 3 karakter."
                        >
                            <input type="text" {...bind('username', 'username')} />
                        </Field>

                        <Field
                            id="register-password"
                            label="Kata sandi"
                            error={errors.password}
                            hint="Minimal 8 karakter."
                        >
                            <input type="password" {...bind('password', 'new-password')} />
                        </Field>

                        <Field
                            id="register-password-confirmation"
                            label="Ulangi kata sandi"
                            error={errors.password_confirmation}
                        >
                            <input type="password" {...bind('password_confirmation', 'new-password')} />
                        </Field>

                        <Button
                            id="register-submit"
                            type="submit"
                            loading={processing}
                            icon={UserPlus}
                            className="w-full"
                        >
                            Daftar
                        </Button>
                    </form>

                    <p className="mt-6 text-center text-sm text-slate-600">
                        Sudah punya akun?{' '}
                        <Link href="/login" className="font-medium text-indigo-700 hover:underline">
                            Masuk
                        </Link>
                    </p>
                </div>
            </div>
        </>
    );
}

Register.layout = (page) => <AppLayout variant="public">{page}</AppLayout>;