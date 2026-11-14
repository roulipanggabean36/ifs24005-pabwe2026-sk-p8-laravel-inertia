<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Admin\Services\AdminUserService;
use App\Features\Post\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class AdminUserServiceTest extends TestCase
{
    use RefreshDatabase;

    private AdminUserService $service;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = $this->app->make(AdminUserService::class);
    }

    public function test_users_are_ordered_by_name_with_post_counts(): void
    {
        $budi = User::factory()->create(['name' => 'Budi', 'username' => 'budi']);
        $ani = User::factory()->create(['name' => 'Ani', 'username' => 'ani']);
        Post::factory()->count(2)->create(['user_id' => $ani->id]);

        $items = $this->service->listUsers(null)->items();

        $this->assertSame(['Ani', 'Budi'], [$items[0]->name, $items[1]->name]);
        $this->assertEquals(2, $items[0]->posts_count);
        $this->assertEquals(0, $items[1]->posts_count);
    }

    public function test_search_matches_name_or_username_case_insensitively(): void
    {
        User::factory()->create(['name' => 'Siti Aminah', 'username' => 'siti']);
        User::factory()->create(['name' => 'Joko', 'username' => 'penulis-joko']);
        User::factory()->create(['name' => 'Rina', 'username' => 'rina']);

        $byName = $this->service->listUsers('AMINAH')->items();
        $byUsername = $this->service->listUsers('PENULIS')->items();

        $this->assertSame(['Siti Aminah'], array_map(fn ($user) => $user->name, $byName));
        $this->assertSame(['Joko'], array_map(fn ($user) => $user->name, $byUsername));
    }

    public function test_search_treats_wildcards_literally(): void
    {
        User::factory()->create(['name' => 'Tes 100%', 'username' => 'u1']);
        User::factory()->create(['name' => 'Tes 1000', 'username' => 'u2']);

        $items = $this->service->listUsers('100%')->items();

        $this->assertSame(['Tes 100%'], array_map(fn ($user) => $user->name, $items));
    }

    public function test_blank_search_returns_everyone_and_paginates(): void
    {
        foreach (range(1, 11) as $number) {
            User::factory()->create(['name' => 'Pengguna '.$number, 'username' => 'pengguna'.$number]);
        }

        $page = $this->service->listUsers('   ');

        $this->assertSame(11, $page->total());
        $this->assertCount(10, $page->items());
        $this->assertSame(2, $page->lastPage());
    }

    public function test_it_lists_posts_and_stats_for_one_user(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->draft()->create(['user_id' => $user->id]);
        Post::factory()->create();

        $this->assertSame(3, $this->service->postsForUser($user, null, null, null)->total());
        $this->assertSame(1, $this->service->postsForUser($user, null, null, 'draft')->total());
        $this->assertSame(
            ['total' => 3, 'published' => 2, 'draft' => 1],
            $this->service->statsForUser($user),
        );
    }

    public function test_it_exports_the_posts_of_one_user(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->create();

        $this->assertCount(2, $this->service->exportForUser($user));
    }
}