import Spinner from './Spinner';

const variants = {
    primary: 'bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500',
    secondary:
        'border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 focus:ring-slate-400',
    danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500',
    success: 'bg-emerald-600 text-white hover:bg-emerald-700 focus:ring-emerald-500',
    warning: 'bg-amber-600 text-white hover:bg-amber-700 focus:ring-amber-500',
    violet: 'bg-violet-600 text-white hover:bg-violet-700 focus:ring-violet-500',
    ghost: 'text-slate-600 hover:bg-slate-100 focus:ring-slate-400',
};

const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
};

/**
 * Kelas tombol yang dapat dipakai juga pada <Link> atau <a>.
 */
export function buttonClasses(variant = 'primary', size = 'md', extra = '') {
    return [
        'inline-flex items-center justify-center gap-2 rounded-lg font-medium transition',
        'focus:outline-none focus:ring-2 focus:ring-offset-1',
        'disabled:cursor-not-allowed disabled:opacity-60',
        sizes[size] ?? sizes.md,
        variants[variant] ?? variants.primary,
        extra,
    ]
        .filter(Boolean)
        .join(' ');
}

export default function Button({
    type = 'button',
    variant = 'primary',
    size = 'md',
    loading = false,
    disabled = false,
    icon: Icon,
    className = '',
    children,
    ...props
}) {
    return (
        <button
            type={type}
            disabled={disabled || loading}
            aria-busy={loading}
            className={buttonClasses(variant, size, className)}
            {...props}
        >
            {loading ? <Spinner /> : Icon ? <Icon className="h-4 w-4" aria-hidden="true" /> : null}
            {children}
        </button>
    );
}