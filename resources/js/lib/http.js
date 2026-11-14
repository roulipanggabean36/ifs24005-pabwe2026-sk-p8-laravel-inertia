function readCookie(name) {
    const match = document.cookie.split('; ').find((row) => row.startsWith(`${name}=`));

    return match ? decodeURIComponent(match.split('=').slice(1).join('=')) : null;
}

/**
 * POST JSON ke endpoint Laravel dengan token CSRF dari cookie XSRF-TOKEN.
 * Selalu mengembalikan { ok, status, data } dan tidak melempar error.
 */
export async function postJson(url, body) {
    let response;

    try {
        response = await fetch(url, {
            method: 'POST',
            credentials: 'same-origin',
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
                'X-Requested-With': 'XMLHttpRequest',
                'X-XSRF-TOKEN': readCookie('XSRF-TOKEN') ?? '',
            },
            body: JSON.stringify(body),
        });
    } catch {
        return {
            ok: false,
            status: 0,
            data: { message: 'Tidak dapat terhubung ke server. Periksa koneksi Anda.' },
        };
    }

    let data = {};

    try {
        data = await response.json();
    } catch {
        data = {};
    }

    return { ok: response.ok, status: response.status, data };
}

/**
 * Ambil pesan kesalahan pertama yang ramah pengguna dari hasil postJson.
 */
export function errorMessage(result) {
    const errors = result?.data?.errors;

    if (errors && typeof errors === 'object') {
        const first = Object.values(errors)[0];

        if (Array.isArray(first) && first.length > 0) {
            return String(first[0]);
        }
    }

    return result?.data?.message || 'Terjadi kesalahan. Silakan coba lagi.';
}