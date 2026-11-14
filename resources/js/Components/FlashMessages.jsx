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