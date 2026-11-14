import { Head, Link, useForm } from '@inertiajs/react';
import { Eye, EyeOff, LogIn } from 'lucide-react';
import { useState } from 'react';
import Button from '../../Components/Button';
import Field, { inputClass } from '../../Components/Field';
import AppLayout from '../../Layouts/AppLayout';

export default function Login() {
    const { data, setData, post, processing, errors, reset } = useForm({
        username: '',
        password: '',
        remember: false,
    });
    const [showPassword, setShowPassword] = useState(false);

    function submit(event) {
        event.preventDefault();
        post('/login', { onFinish: () => reset('password') });
    }

    return (
        <>
            <Head title="Masuk" />

            <div className="mx-auto flex max-w-md flex-col px-4 py-12 sm:py-16">
                <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
                    <h1 className="text-2xl font-bold text-slate-900">Masuk ke BlogVerse Pro</h1>
                    <p className="mt-1 text-sm text-slate-600">
                        Gunakan username dan kata sandi Anda untuk mengelola artikel.
                    </p>

                    <form onSubmit={submit} noValidate className="mt-6 space-y-5">
                        <Field id="login-username" label="Username" error={errors.username}>
                            <input
                                id="login-username"
                                name="username"
                                type="text"
                                autoComplete="username"
                                value={data.username}
                                onChange={(event) => setData('username', event.target.value)}
                                aria-invalid={Boolean(errors.username)}
                                aria-describedby={errors.username ? 'login-username-error' : undefined}
                                className={inputClass(Boolean(errors.username))}
                            />
                        </Field>

                        <Field id="login-password" label="Kata sandi" error={errors.password}>
                            <div className="relative">
                                <input
                                    id="login-password"
                                    name="password"
                                    type={showPassword ? 'text' : 'password'}
                                    autoComplete="current-password"
                                    value={data.password}
                                    onChange={(event) => setData('password', event.target.value)}
                                    aria-invalid={Boolean(errors.password)}
                                    aria-describedby={errors.password ? 'login-password-error' : undefined}
                                    className={`${inputClass(Boolean(errors.password))} pr-10`}
                                />
                                <button
                                    type="button"
                                    onClick={() => setShowPassword((value) => !value)}
                                    aria-label={showPassword ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'}
                                    className="absolute inset-y-0 right-0 flex items-center px-3 text-slate-500 hover:text-slate-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                                >
                                    {showPassword ? (
                                        <EyeOff className="h-4 w-4" aria-hidden="true" />
                                    ) : (
                                        <Eye className="h-4 w-4" aria-hidden="true" />
                                    )}
                                </button>
                            </div>
                        </Field>

                        <label className="flex items-center gap-2 text-sm text-slate-700">
                            <input
                                id="login-remember"
                                type="checkbox"
                                checked={data.remember}
                                onChange={(event) => setData('remember', event.target.checked)}
                                className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                            />
                            Ingat saya
                        </label>

                        <Button
                            id="login-submit"
                            type="submit"
                            loading={processing}
                            icon={LogIn}
                            className="w-full"
                        >
                            Masuk
                        </Button>
                    </form>

                    <p className="mt-6 text-center text-sm text-slate-600">
                        Belum punya akun?{' '}
                        <Link href="/register" className="font-medium text-indigo-700 hover:underline">
                            Daftar sebagai penulis
                        </Link>
                    </p>
                </div>
            </div>
        </>
    );
}

Login.layout = (page) => <AppLayout variant="public">{page}</AppLayout>;