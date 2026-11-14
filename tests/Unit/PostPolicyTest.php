<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Models\Post;
use App\Features\Post\Policies\PostPolicy;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class PostPolicyTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_may_view_update_and_delete(): void
    {
        $owner = User::factory()->create();
        $post = Post::factory()->create(['user_id' => $owner->id]);
        $policy = new PostPolicy();

        $this->assertTrue($policy->view($owner, $post));
        $this->assertTrue($policy->update($owner, $post));
        $this->assertTrue($policy->delete($owner, $post));
    }

    public function test_other_users_and_admins_may_not_manage_the_post(): void
    {
        $post = Post::factory()->create();
        $policy = new PostPolicy();

        foreach ([User::factory()->create(), User::factory()->admin()->create()] as $other) {
            $this->assertFalse($policy->view($other, $post));
            $this->assertFalse($policy->update($other, $post));
            $this->assertFalse($policy->delete($other, $post));
        }
    }
}