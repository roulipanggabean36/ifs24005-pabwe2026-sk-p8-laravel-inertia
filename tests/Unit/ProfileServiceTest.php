<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Profile\Services\ProfileService;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

final class ProfileServiceTest extends TestCase
{
    use RefreshDatabase;

    private ProfileService $service;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
        $this->service = new ProfileService();
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function user(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'name' => 'Nama Lama',
            'username' => 'lama',
            'password' => 'password-lama',
        ], $overrides));
    }

    public function test_it_updates_identity_and_keeps_the_password_when_blank(): void
    {
        $user = $this->user();

        foreach ([[], ['password' => null], ['password' => '']] as $extra) {
            $updated = $this->service->update($user, ['name' => 'Nama Baru', 'username' => 'baru'] + $extra);

            $this->assertSame('Nama Baru', $updated->name);
            $this->assertSame('baru', $updated->username);
            $this->assertTrue(Hash::check('password-lama', $updated->password));
        }
    }

    public function test_it_changes_the_password(): void
    {
        $user = $this->user();

        $updated = $this->service->update($user, [
            'name' => 'Nama Lama',
            'username' => 'lama',
            'password' => 'password-baru',
        ]);

        $this->assertTrue(Hash::check('password-baru', $updated->password));
        $this->assertFalse(Hash::check('password-lama', $updated->password));
    }

    public function test_it_uploads_a_photo(): void
    {
        $user = $this->user();

        $updated = $this->service->update(
            $user,
            ['name' => 'Nama Lama', 'username' => 'lama'],
            UploadedFile::fake()->image('foto.jpg'),
        );

        $this->assertStringStartsWith('profile-photos/', (string) $updated->profile_photo_path);
        Storage::disk('public')->assertExists((string) $updated->profile_photo_path);
    }

    public function test_it_replaces_an_existing_photo(): void
    {
        Storage::disk('public')->put('profile-photos/lama.jpg', 'x');
        $user = $this->user(['profile_photo_path' => 'profile-photos/lama.jpg']);

        $updated = $this->service->update(
            $user,
            ['name' => 'Nama Lama', 'username' => 'lama'],
            UploadedFile::fake()->image('baru.jpg'),
        );

        Storage::disk('public')->assertMissing('profile-photos/lama.jpg');
        Storage::disk('public')->assertExists((string) $updated->profile_photo_path);
    }

    public function test_a_new_photo_wins_over_the_remove_flag(): void
    {
        $user = $this->user();

        $updated = $this->service->update(
            $user,
            ['name' => 'Nama Lama', 'username' => 'lama'],
            UploadedFile::fake()->image('baru.jpg'),
            true,
        );

        $this->assertNotNull($updated->profile_photo_path);
    }

    public function test_it_removes_the_photo(): void
    {
        Storage::disk('public')->put('profile-photos/lama.jpg', 'x');
        $user = $this->user(['profile_photo_path' => 'profile-photos/lama.jpg']);

        $updated = $this->service->update($user, ['name' => 'Nama Lama', 'username' => 'lama'], null, true);

        $this->assertNull($updated->profile_photo_path);
        Storage::disk('public')->assertMissing('profile-photos/lama.jpg');
    }

    public function test_remove_flag_without_a_photo_is_harmless(): void
    {
        $user = $this->user();

        $updated = $this->service->update($user, ['name' => 'Nama Lama', 'username' => 'lama'], null, true);

        $this->assertNull($updated->profile_photo_path);
    }

    public function test_it_leaves_the_photo_untouched_by_default(): void
    {
        Storage::disk('public')->put('profile-photos/lama.jpg', 'x');
        $user = $this->user(['profile_photo_path' => 'profile-photos/lama.jpg']);

        $updated = $this->service->update($user, ['name' => 'Nama Lama', 'username' => 'lama']);

        $this->assertSame('profile-photos/lama.jpg', $updated->profile_photo_path);
        Storage::disk('public')->assertExists('profile-photos/lama.jpg');
    }
}