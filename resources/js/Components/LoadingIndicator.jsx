import { router } from '@inertiajs/react';
import { useEffect, useRef, useState } from 'react';
import Spinner from './Spinner';

/**
 * Top progress bar + floating pill "Memproses tindakan..." untuk setiap request Inertia.
 */
export default function LoadingIndicator() {
    const [active, setActive] = useState(false);
    const [width, setWidth] = useState(0);
    const tickRef = useRef(null);
    const hideRef = useRef(null);

    useEffect(() => {
        const stopTick = () => {
            if (tickRef.current !== null) {
                clearInterval(tickRef.current);
                tickRef.current = null;
            }
        };

        const offStart = router.on('start', () => {
            clearTimeout(hideRef.current);
            stopTick();
            setActive(true);
            setWidth(8);
            tickRef.current = setInterval(() => {
                setWidth((current) => current + (90 - current) * 0.12);
            }, 200);
        });

        const offFinish = router.on('finish', () => {
            stopTick();
            setWidth(100);
            hideRef.current = setTimeout(() => {
                setActive(false);
                setWidth(0);
            }, 300);
        });

        return () => {
            offStart();
            offFinish();
            stopTick();
            clearTimeout(hideRef.current);
        };
    }, []);

    return (
        <>
            <div className="pointer-events-none fixed inset-x-0 top-0 z-[60] h-1" aria-hidden="true">
                <div
                    className="h-full bg-indigo-600 transition-[width] duration-200 ease-out"
                    style={{ width: `${width}%`, opacity: active ? 1 : 0 }}
                />
            </div>

            {active && (
                <div
                    role="status"
                    aria-live="polite"
                    className="pointer-events-none fixed bottom-6 left-1/2 z-[60] flex -translate-x-1/2 items-center gap-2 rounded-full bg-slate-900 px-4 py-2 text-sm font-medium text-white shadow-lg"
                >
                    <Spinner />
                    Memproses tindakan...
                </div>
            )}
        </>
    );
}