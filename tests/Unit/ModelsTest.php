<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Models\Post;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

final class ModelsTest extends TestCase
{
    use RefreshDatabase;

    public function test_post_cover_url_is_null_without_cover(): void
    {
        $post = Post::factory()->create(['cover_image_path' => null]);

        $this->assertNull($post->cover_url);
    }

    public function test_post_cover_url_points_to_public_storage(): void
    {
        $post = Post::factory()->create(['cover_image_path' => 'covers/a.jpg']);

        $this->assertSame('/storage/covers/a.jpg', $post->cover_url);
        $this->assertArrayHasKey('cover_url', $post->toArray());
    }

    public function test_post_belongs_to_user(): void
    {
        $user = User::factory()->create();
        $post = Post::factory()->create(['user_id' => $user->id]);

        $this->assertTrue($post->user->is($user));
    }

    public function test_post_casts_publication_fields(): void
    {
        $post = Post::factory()->published()->create()->fresh();

        $this->assertTrue($post->is_published);
        $this->assertInstanceOf(CarbonInterface::class, $post->published_at);

        $draft = Post::factory()->draft()->create()->fresh();

        $this->assertFalse($draft->is_published);
        $this->assertNull($draft->published_at);
    }

    public function test_published_scope_excludes_drafts(): void
    {
        Post::factory()->count(2)->published()->create();
        Post::factory()->draft()->create();

        $this->assertSame(2, Post::query()->published()->count());
    }

    public function test_user_role_helpers(): void
    {
        $this->assertTrue(User::factory()->admin()->create()->isAdmin());
        $this->assertFalse(User::factory()->member()->create()->isAdmin());
        $this->assertSame('admin', User::ROLE_ADMIN);
        $this->assertSame('member', User::ROLE_MEMBER);
    }

    public function test_user_profile_photo_url(): void
    {
        $user = User::factory()->create(['profile_photo_path' => null]);

        $this->assertNull($user->profilePhotoUrl());

        $user->profile_photo_path = 'profile-photos/a.jpg';

        $this->assertSame('/storage/profile-photos/a.jpg', $user->profilePhotoUrl());
    }

    public function test_user_password_is_hashed_and_hidden(): void
    {
        $user = User::factory()->create(['password' => 'rahasia123']);

        $this->assertNotSame('rahasia123', $user->password);
        $this->assertTrue(Hash::check('rahasia123', $user->password));
        $this->assertArrayNotHasKey('password', $user->toArray());
        $this->assertArrayNotHasKey('remember_token', $user->toArray());
    }

    public function test_user_has_many_posts(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);

        $this->assertCount(2, $user->posts);
    }

    public function test_deleting_user_cascades_to_posts(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);

        $user->delete();

        $this->assertDatabaseCount('posts', 0);
    }
}