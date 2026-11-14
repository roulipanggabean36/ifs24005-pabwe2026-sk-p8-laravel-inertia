import { useEffect, useRef } from 'react';

const FOCUSABLE =
    'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Perilaku dialog aksesibel: fokus masuk, jebakan Tab, ESC menutup,
 * kunci scroll body, dan fokus dikembalikan saat ditutup.
 */
export default function useDialog(open, dialogRef, onClose) {
    const closeRef = useRef(onClose);

    useEffect(() => {
        closeRef.current = onClose;
    }, [onClose]);

    useEffect(() => {
        const dialog = dialogRef.current;

        if (!open || !dialog) {
            return undefined;
        }

        const previouslyFocused = document.activeElement;
        const previousOverflow = document.body.style.overflow;

        document.body.style.overflow = 'hidden';
        (dialog.querySelector('[data-autofocus]') ?? dialog).focus();

        function onKeyDown(event) {
            if (event.key === 'Escape') {
                event.stopPropagation();
                closeRef.current?.();

                return;
            }

            if (event.key !== 'Tab') {
                return;
            }

            const items = [...dialog.querySelectorAll(FOCUSABLE)].filter(
                (element) => element.offsetParent !== null,
            );

            if (items.length === 0) {
                event.preventDefault();

                return;
            }

            const first = items[0];
            const last = items[items.length - 1];

            if (event.shiftKey && document.activeElement === first) {
                event.preventDefault();
                last.focus();
            } else if (!event.shiftKey && document.activeElement === last) {
                event.preventDefault();
                first.focus();
            }
        }

        document.addEventListener('keydown', onKeyDown);

        return () => {
            document.removeEventListener('keydown', onKeyDown);
            document.body.style.overflow = previousOverflow;

            if (previouslyFocused && typeof previouslyFocused.focus === 'function') {
                previouslyFocused.focus();
            }
        };
    }, [open, dialogRef]);
}