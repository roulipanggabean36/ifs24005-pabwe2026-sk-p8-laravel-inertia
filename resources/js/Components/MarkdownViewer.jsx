import Viewer from '@toast-ui/editor/dist/toastui-editor-viewer';
import '@toast-ui/editor/dist/toastui-editor-viewer.css';
import { useEffect, useRef } from 'react';
import { sanitizeHtml } from '../lib/sanitize';

/**
 * TOAST UI Viewer. Konten disanitasi dengan DOMPurify, dibersihkan saat unmount.
 */
export default function MarkdownViewer({ content }) {
    const elRef = useRef(null);

    useEffect(() => {
        const viewer = new Viewer({
            el: elRef.current,
            initialValue: content ?? '',
            customHTMLSanitizer: sanitizeHtml,
        });

        return () => viewer.destroy();
    }, [content]);

    return <div ref={elRef} />;
}