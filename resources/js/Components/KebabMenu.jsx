import { EllipsisVertical } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

const tones = {
    primary: 'text-indigo-700 hover:bg-indigo-50',
    danger: 'text-red-600 hover:bg-red-50',
};

/**
 * Menu tindakan vertical dots (â‹®).
 * items: [{ label, icon, onClick, tone: 'primary' | 'danger' }]
 */
export default function KebabMenu({ items, label = 'Menu tindakan' }) {
    const [open, setOpen] = useState(false);
    const rootRef = useRef(null);

    useEffect(() => {
        if (!open) {
            return undefined;
        }

        const onPointerDown = (event) => {
            if (rootRef.current && !rootRef.current.contains(event.target)) {
                setOpen(false);
            }
        };
        const onKeyDown = (event) => {
            if (event.key === 'Escape') {
                setOpen(false);
            }
        };

        document.addEventListener('mousedown', onPointerDown);
        document.addEventListener('keydown', onKeyDown);

        return () => {
            document.removeEventListener('mousedown', onPointerDown);
            document.removeEventListener('keydown', onKeyDown);
        };
    }, [open]);

    return (
        <div ref={rootRef} className="relative inline-block text-left">
            <button
                type="button"
                aria-label={label}
                aria-haspopup="menu"
                aria-expanded={open}
                onClick={() => setOpen((value) => !value)}
                className="rounded-lg p-2 text-slate-500 hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
                <EllipsisVertical className="h-5 w-5" aria-hidden="true" />
            </button>

            {open && (
                <div
                    role="menu"
                    className="absolute right-0 z-30 mt-1 w-44 rounded-lg border border-slate-200 bg-white py-1 shadow-lg"
                >
                    {items.map((item) => {
                        const Icon = item.icon;

                        return (
                            <button
                                key={item.label}
                                type="button"
                                role="menuitem"
                                onClick={() => {
                                    setOpen(false);
                                    item.onClick();
                                }}
                                className={`flex w-full items-center gap-2 px-3 py-2 text-left text-sm ${
                                    tones[item.tone ?? 'primary']
                                }`}
                            >
                                <Icon className="h-4 w-4" aria-hidden="true" />
                                {item.label}
                            </button>
                        );
                    })}
                </div>
            )}
        </div>
    );
}