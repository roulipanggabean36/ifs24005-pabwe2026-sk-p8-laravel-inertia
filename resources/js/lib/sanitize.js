import DOMPurify from 'dompurify';

/**
 * Sanitasi HTML hasil render Markdown agar aman dari XSS.
 */
export function sanitizeHtml(html) {
    return DOMPurify.sanitize(html, { USE_PROFILES: { html: true } });
}