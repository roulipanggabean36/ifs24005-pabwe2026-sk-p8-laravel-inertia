<?php

declare(strict_types=1);

namespace App\Features\Auth\Actions;

use App\Models\User;
use Illuminate\Support\Facades\Auth;

class RegisterUserAction
{
    /**
     * @param  array{name: string, username: string, password: string}  $data
     */
    public function execute(array $data): User
    {
        $user = User::query()->create([
            'name' => $data['name'],
            'username' => $data['username'],
            'password' => $data['password'],
            'role' => User::ROLE_MEMBER,
        ]);

        Auth::login($user);

        return $user;
    }
}