<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::query()->create([
            'name' => 'Administrator',
            'username' => 'admin',
            'password' => 'admin',
            'role' => User::ROLE_ADMIN,
        ]);

        $member = User::query()->create([
            'name' => 'Penulis Demo',
            'username' => 'member',
            'password' => 'member',
            'role' => User::ROLE_MEMBER,
        ]);

        $this->seedPosts($member, [
            [
                'Memulai Belajar Laravel dari Nol',
                PostCategory::Teknologi,
                'Panduan singkat memahami routing, controller, dan Eloquent untuk pemula.',
                "## Mengapa Laravel?\n\nLaravel menawarkan struktur yang rapi dan ekosistem yang lengkap.\n\n- Routing yang ekspresif\n- Eloquent ORM\n- Migrasi database\n\n> Mulailah dari proyek kecil, lalu tingkatkan perlahan.",
                true,
                1,
            ],
            [
                'Tips Belajar Efektif untuk Mahasiswa',
                PostCategory::Pendidikan,
                'Strategi belajar terstruktur agar waktu tidak terbuang percuma.',
                "## Atur Jadwal\n\n1. Tentukan target mingguan\n2. Gunakan teknik pomodoro\n3. Evaluasi setiap akhir pekan\n\nKonsistensi lebih penting daripada durasi.",
                true,
                3,
            ],
            [
                'Membangun Rutinitas Pagi yang Produktif',
                PostCategory::GayaHidup,
                'Langkah sederhana memulai hari dengan fokus dan energi.',
                "## Mulai Kecil\n\nBangun lebih awal selama 15 menit, minum air putih, lalu tulis tiga prioritas hari ini.\n\n**Kunci:** lakukan setiap hari.",
                true,
                5,
            ],
            [
                'Dasar-Dasar Memulai Bisnis Digital',
                PostCategory::Bisnis,
                'Mengenal validasi ide, target pasar, dan model pendapatan.',
                "## Validasi Dulu\n\nSebelum membangun produk, pastikan ada masalah nyata yang ingin diselesaikan.\n\n- Wawancarai calon pengguna\n- Buat prototipe sederhana\n- Ukur minat pasar",
                true,
                7,
            ],
            [
                'Catatan Pribadi tentang Kerja Jarak Jauh',
                PostCategory::Opini,
                'Refleksi pengalaman bekerja dari rumah (masih draf).',
                "## Draf\n\nBekerja jarak jauh memberi fleksibilitas, namun butuh disiplin tinggi.",
                false,
                0,
            ],
            [
                'Rencana Konten Bulan Depan',
                PostCategory::Umum,
                'Daftar ide artikel yang akan ditulis (masih draf).',
                "## Ide Artikel\n\n- Review buku\n- Tutorial Inertia\n- Tips produktivitas",
                false,
                0,
            ],
        ]);

        $this->seedPosts($admin, [
            [
                'Selamat Datang di BlogVerse Pro',
                PostCategory::Umum,
                'Platform publikasi artikel multi-tier untuk semua penulis.',
                "## Halo, Penulis!\n\nBlogVerse Pro adalah tempat berbagi tulisan. Daftar, tulis, lalu terbitkan.",
                true,
                10,
            ],
            [
                'Panduan Menulis Artikel yang Menarik',
                PostCategory::Pendidikan,
                'Struktur judul, pembuka, isi, dan penutup yang memikat pembaca.',
                "## Struktur Dasar\n\n1. Judul yang jelas\n2. Pembuka yang kuat\n3. Isi yang runtut\n4. Penutup yang berkesan",
                true,
                12,
            ],
            [
                'Draf Pengumuman Pemeliharaan Sistem',
                PostCategory::Teknologi,
                'Jadwal pemeliharaan sistem (belum dipublikasikan).',
                "## Jadwal\n\nAkan diumumkan setelah dikonfirmasi tim infrastruktur.",
                false,
                0,
            ],
        ]);

        $this->command?->info('Seeded: '.User::query()->count().' users, '.Post::query()->count().' posts.');
    }

    /**
     * @param  list<array{0: string, 1: PostCategory, 2: string, 3: string, 4: bool, 5: int}>  $items
     */
    private function seedPosts(User $user, array $items): void
    {
        foreach ($items as [$title, $category, $excerpt, $content, $published, $daysAgo]) {
            Post::query()->create([
                'user_id' => $user->id,
                'title' => $title,
                'slug' => Str::slug($title),
                'category' => $category->value,
                'excerpt' => $excerpt,
                'content' => $content,
                'is_published' => $published,
                'published_at' => $published ? now()->subDays($daysAgo) : null,
            ]);
        }
    }
}