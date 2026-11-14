import { router } from '@inertiajs/react';
import { Save, Sparkles } from 'lucide-react';
import { useState } from 'react';
import { errorMessage, postJson } from '../lib/http';
import Button from './Button';
import Field, { inputClass } from './Field';
import Modal from './Modal';
import { CategoryBadge } from './Ui';

/**
 * Generator artikel via OpenAI: hasilkan dulu (tidak disimpan), pilih, lalu simpan sebagai draf.
 */
export default function AiGeneratorModal({ max, onClose }) {
    const [topic, setTopic] = useState('');
    const [count, setCount] = useState('3');
    const [fieldErrors, setFieldErrors] = useState({});
    const [message, setMessage] = useState('');
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [items, setItems] = useState([]);
    const [selected, setSelected] = useState([]);

    const selectedCount = selected.filter(Boolean).length;

    async function generate(event) {
        event.preventDefault();
        setMessage('');

        const next = {};
        const amount = Number(count);

        if (topic.trim() === '') {
            next.topic = 'Topik wajib diisi.';
        }

        if (count === '' || !Number.isInteger(amount) || amount < 1 || amount > max) {
            next.count = `Jumlah harus bilangan bulat antara 1 dan ${max}.`;
        }

        setFieldErrors(next);

        if (Object.keys(next).length > 0) {
            return;
        }

        setLoading(true);

        const result = await postJson('/dashboard/posts/ai-generate', {
            topic: topic.trim(),
            count: amount,
        });

        setLoading(false);

        if (!result.ok) {
            setMessage(errorMessage(result));

            return;
        }

        const list = Array.isArray(result.data.items) ? result.data.items : [];

        setItems(list);
        setSelected(list.map(() => true));
    }

    function toggle(index) {
        setSelected((current) => current.map((value, i) => (i === index ? !value : value)));
    }

    function save() {
        const chosen = items.filter((_, index) => selected[index]);

        if (chosen.length === 0) {
            setMessage('Pilih minimal satu artikel untuk disimpan.');

            return;
        }

        setMessage('');

        router.post(
            '/dashboard/posts/ai-save',
            { items: chosen },
            {
                preserveScroll: true,
                onStart: () => setSaving(true),
                onError: (errors) =>
                    setMessage(Object.values(errors)[0] ?? 'Artikel gagal disimpan. Silakan coba lagi.'),
                onSuccess: onClose,
                onFinish: () => setSaving(false),
            },
        );
    }

    return (
        <Modal
            open
            title="Generator Artikel AI"
            tone="ai"
            onClose={onClose}
            footer={
                <>
                    <Button variant="secondary" onClick={onClose} disabled={loading || saving}>
                        Batal
                    </Button>
                    <Button
                        id="ai-generate"
                        type="submit"
                        form="ai-form"
                        variant={items.length > 0 ? 'secondary' : 'violet'}
                        loading={loading}
                        disabled={saving}
                        icon={Sparkles}
                    >
                        {items.length > 0 ? 'Hasilkan Ulang' : 'Hasilkan Artikel'}
                    </Button>
                    {items.length > 0 && (
                        <Button
                            id="ai-save"
                            variant="violet"
                            icon={Save}
                            loading={saving}
                            disabled={loading}
                            onClick={save}
                        >
                            Simpan {selectedCount} Artikel sebagai Draf
                        </Button>
                    )}
                </>
            }
        >
            <form id="ai-form" onSubmit={generate} noValidate className="grid gap-6 sm:grid-cols-3">
                <div className="sm:col-span-2">
                    <Field id="ai-topic" label="Topik artikel" error={fieldErrors.topic}>
                        <input
                            id="ai-topic"
                            type="text"
                            data-autofocus
                            maxLength={200}
                            value={topic}
                            onChange={(event) => setTopic(event.target.value)}
                            placeholder="Contoh: produktivitas belajar untuk mahasiswa"
                            aria-invalid={Boolean(fieldErrors.topic)}
                            aria-describedby={fieldErrors.topic ? 'ai-topic-error' : undefined}
                            className={inputClass(Boolean(fieldErrors.topic))}
                        />
                    </Field>
                </div>

                <Field
                    id="ai-count"
                    label="Jumlah artikel"
                    error={fieldErrors.count}
                    hint={`Antara 1 dan ${max}.`}
                >
                    <input
                        id="ai-count"
                        type="number"
                        inputMode="numeric"
                        min={1}
                        max={max}
                        step={1}
                        value={count}
                        onChange={(event) => setCount(event.target.value)}
                        aria-invalid={Boolean(fieldErrors.count)}
                        aria-describedby={fieldErrors.count ? 'ai-count-error' : 'ai-count-hint'}
                        className={inputClass(Boolean(fieldErrors.count))}
                    />
                </Field>
            </form>

            {message && (
                <p
                    role="alert"
                    className="mt-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
                >
                    {message}
                </p>
            )}

            {loading && (
                <p role="status" className="mt-6 text-sm text-slate-600">
                    AI sedang menulis artikel, mohon tunggu sebentar...
                </p>
            )}

            {items.length > 0 && (
                <section className="mt-8" aria-labelledby="ai-result-title">
                    <h3 id="ai-result-title" className="text-lg font-semibold text-slate-900">
                        Hasil ({items.length} artikel)
                    </h3>
                    <p className="mt-1 text-sm text-slate-600">
                        Hasil belum disimpan. Pilih artikel yang ingin disimpan sebagai draf.
                    </p>

                    <ul className="mt-4 space-y-4">
                        {items.map((item, index) => (
                            <li
                                key={`${index}-${item.title}`}
                                className="rounded-xl border border-slate-200 bg-white p-4"
                            >
                                <label
                                    htmlFor={`ai-item-${index}`}
                                    className="flex items-start gap-3"
                                >
                                    <input
                                        id={`ai-item-${index}`}
                                        type="checkbox"
                                        checked={Boolean(selected[index])}
                                        onChange={() => toggle(index)}
                                        className="mt-1 h-4 w-4 rounded border-slate-300 text-violet-600 focus:ring-violet-500"
                                    />
                                    <span className="min-w-0 flex-1">
                                        <span className="block font-medium text-slate-900">
                                            {item.title}
                                        </span>
                                        <span className="mt-1 block">
                                            <CategoryBadge category={item.category} />
                                        </span>
                                        {item.excerpt && (
                                            <span className="mt-2 block text-sm text-slate-600">
                                                {item.excerpt}
                                            </span>
                                        )}
                                    </span>
                                </label>

                                <details className="mt-3 pl-7">
                                    <summary className="text-sm font-medium text-violet-700">
                                        Lihat isi artikel
                                    </summary>
                                    <pre className="mt-2 max-h-64 overflow-y-auto whitespace-pre-wrap rounded-lg bg-slate-50 p-3 text-xs text-slate-700">
                                        {item.content}
                                    </pre>
                                </details>
                            </li>
                        ))}
                    </ul>
                </section>
            )}
        </Modal>
    );
}