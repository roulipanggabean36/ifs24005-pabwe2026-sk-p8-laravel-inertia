import Editor from '@toast-ui/editor';
import '@toast-ui/editor/dist/toastui-editor.css';
import { useEffect, useRef } from 'react';
import { sanitizeHtml } from '../lib/sanitize';

/**
 * TOAST UI Editor (mode Markdown). Nilai awal dibaca sekali saat mount;
 * gunakan `key` untuk memaksa inisialisasi ulang. Dibersihkan saat unmount.
 */
export default function MarkdownEditor({
    value = '',
    onChange,
    height = '420px',
    placeholder = 'Tulis artikel dalam format Markdown...',
    label = 'Editor Markdown',
}) {
    const elRef = useRef(null);
    const changeRef = useRef(onChange);

    useEffect(() => {
        changeRef.current = onChange;
    }, [onChange]);

    useEffect(() => {
        let editor = null;

        editor = new Editor({
            el: elRef.current,
            initialValue: value ?? '',
            initialEditType: 'markdown',
            previewStyle: 'vertical',
            height,
            placeholder,
            usageStatistics: false,
            customHTMLSanitizer: sanitizeHtml,
            events: {
                change: () => {
                    if (editor) {
                        changeRef.current?.(editor.getMarkdown());
                    }
                },
            },
        });

        return () => {
            editor.destroy();
            editor = null;
        };
        // Nilai awal hanya dibaca saat mount.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    return <div ref={elRef} role="group" aria-label={label} />;
}