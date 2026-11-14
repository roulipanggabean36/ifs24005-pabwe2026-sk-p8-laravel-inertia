<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

final class ProfileTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
    }

    public function test_guests_are_redirected_to_login(): void
    {
        $this->get('/profile')->assertRedirect(route('login'));
        $this->put('/profile', [])->assertRedirect(route('login'));
    }

    public function test_the_page_shows_the_current_profile(): void
    {
        $user = User::factory()->create([
            'name' => 'Ani',
            'username' => 'ani',
            'profile_photo_path' => 'profile-photos/a.jpg',
        ]);

        $this->actingAs($user)->get('/profile')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('Profile/Edit')
            ->where('profile', [
                'name' => 'Ani',
                'username' => 'ani',
                'photo_url' => '/storage/profile-photos/a.jpg',
            ]));
    }

    public function test_a_member_updates_name_and_username(): void
    {
        $user = User::factory()->create(['name' => 'Lama', 'username' => 'lama', 'password' => 'rahasia123']);

        $this->actingAs($user)
            ->put('/profile', ['name' => 'Baru', 'username' => 'baru'])
            ->assertRedirect(route('profile.edit'))
            ->assertSessionHas('success', 'Profil berhasil diperbarui.');

        $user->refresh();

        $this->assertSame('Baru', $user->name);
        $this->assertSame('baru', $user->username);
        $this->assertTrue(Hash::check('rahasia123', $user->password));
    }

    public function test_an_admin_can_update_the_own_profile(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin)
            ->put('/profile', ['name' => 'Admin Baru', 'username' => 'adminbaru'])
            ->assertRedirect(route('profile.edit'));

        $this->assertSame('Admin Baru', $admin->refresh()->name);
        $this->assertSame('admin', $admin->role);
    }

    public function test_the_current_username_is_not_a_conflict(): void
    {
        $user = User::factory()->create(['username' => 'sama']);

        $this->actingAs($user)
            ->put('/profile', ['name' => 'Nama', 'username' => 'sama'])
            ->assertSessionHasNoErrors();
    }

    public function test_a_username_owned_by_someone_else_is_rejected(): void
    {
        User::factory()->create(['username' => 'dipakai']);
        $user = User::factory()->create(['username' => 'saya']);

        $this->actingAs($user)
            ->from('/profile')
            ->put('/profile', ['name' => 'Nama', 'username' => 'dipakai'])
            ->assertSessionHasErrors(['username' => 'Username sudah digunakan.']);

        $this->assertSame('saya', $user->refresh()->username);
    }

    public function test_required_fields_and_username_format_are_validated(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->from('/profile')
            ->put('/profile', ['name' => '', 'username' => 'nama pengguna'])
            ->assertSessionHasErrors(['name' => 'Nama wajib diisi.', 'username']);
    }

    public function test_the_password_can_be_changed(): void
    {
        $user = User::factory()->create(['password' => 'password-lama']);

        $this->actingAs($user)
            ->put('/profile', [
                'name' => $user->name,
                'username' => $user->username,
                'password' => 'password-baru',
                'password_confirmation' => 'password-baru',
            ])
            ->assertSessionHasNoErrors();

        $this->assertTrue(Hash::check('password-baru', $user->refresh()->password));
    }

    public function test_a_blank_password_keeps_the_old_one(): void
    {
        $user = User::factory()->create(['password' => 'password-lama']);

        $this->actingAs($user)
            ->put('/profile', ['name' => 'Nama', 'username' => $user->username, 'password' => ''])
            ->assertSessionHasNoErrors();

        $this->assertTrue(Hash::check('password-lama', $user->refresh()->password));
    }

    public function test_the_new_password_must_be_confirmed_and_long_enough(): void
    {
        $user = User::factory()->create(['password' => 'password-lama']);
        $base = ['name' => $user->name, 'username' => $user->username];

        $this->actingAs($user)->from('/profile')
            ->put('/profile', $base + ['password' => 'password-baru', 'password_confirmation' => 'berbeda'])
            ->assertSessionHasErrors('password');

        $this->from('/profile')
            ->put('/profile', $base + ['password' => 'pendek', 'password_confirmation' => 'pendek'])
            ->assertSessionHasErrors('password');

        $this->assertTrue(Hash::check('password-lama', $user->refresh()->password));
    }

    public function test_a_photo_can_be_uploaded_and_replaced(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->put('/profile', [
                'name' => $user->name,
                'username' => $user->username,
                'photo' => UploadedFile::fake()->image('satu.jpg', 200, 200),
            ])
            ->assertSessionHasNoErrors();

        $first = (string) $user->refresh()->profile_photo_path;

        $this->assertStringStartsWith('profile-photos/', $first);
        Storage::disk('public')->assertExists($first);

        $this->put('/profile', [
            'name' => $user->name,
            'username' => $user->username,
            'photo' => UploadedFile::fake()->image('dua.png', 200, 200),
        ]);

        $second = (string) $user->refresh()->profile_photo_path;

        Storage::disk('public')->assertMissing($first);
        Storage::disk('public')->assertExists($second);
    }

    public function test_the_photo_can_be_removed(): void
    {
        Storage::disk('public')->put('profile-photos/lama.jpg', 'x');
        $user = User::factory()->create(['profile_photo_path' => 'profile-photos/lama.jpg']);

        $this->actingAs($user)
            ->put('/profile', ['name' => $user->name, 'username' => $user->username, 'remove_photo' => 1])
            ->assertSessionHasNoErrors();

        $this->assertNull($user->refresh()->profile_photo_path);
        Storage::disk('public')->assertMissing('profile-photos/lama.jpg');
    }

    public function test_invalid_photos_are_rejected(): void
    {
        $user = User::factory()->create();
        $base = ['name' => $user->name, 'username' => $user->username];

        $this->actingAs($user);

        foreach ([
            UploadedFile::fake()->create('dokumen.pdf', 10, 'application/pdf'),
            UploadedFile::fake()->image('animasi.gif'),
            UploadedFile::fake()->image('besar.jpg')->size(3000),
        ] as $file) {
            $this->from('/profile')
                ->put('/profile', $base + ['photo' => $file])
                ->assertSessionHasErrors('photo');
        }

        $this->assertNull($user->refresh()->profile_photo_path);
    }
}