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