<?php

declare(strict_types=1);

namespace App\Features\Profile\Services;

use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class ProfileService
{
    /**
     * @param  array{name: string, username: string, password?: string|null}  $data
     */
    public function update(
        User $user,
        array $data,
        ?UploadedFile $photo = null,
        bool $removePhoto = false,
    ): User {
        $attributes = [
            'name' => $data['name'],
            'username' => $data['username'],
        ];

        if (! empty($data['password'])) {
            $attributes['password'] = $data['password'];
        }

        if ($photo !== null) {
            $this->deletePhoto($user);
            $attributes['profile_photo_path'] = $photo->store('profile-photos', 'public');
        } elseif ($removePhoto) {
            $this->deletePhoto($user);
            $attributes['profile_photo_path'] = null;
        }

        $user->update($attributes);

        return $user->refresh();
    }

    private function deletePhoto(User $user): void
    {
        if ($user->profile_photo_path !== null) {
            Storage::disk('public')->delete($user->profile_photo_path);
        }
    }
}