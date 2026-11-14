# fase-5a.ps1 - jalankan dari root proyek
function W($path, $content) {
  $content = $content -replace "`r`n", "`n"
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK  $path"
}

if (-not (Test-Path .\artisan)) {
  Write-Host "GAGAL: jalankan dari root proyek Laravel." -ForegroundColor Red
  exit 1
}
if (-not (Test-Path 'app/Providers/AppServiceProvider.php') -or -not (Test-Path 'app/Features/Ai/Services/OpenAiPostGeneratorService.php')) {
  Write-Host "GAGAL: kode aplikasi (Fase 3) belum lengkap." -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------
# 1. Hapus contoh test bawaan
# ---------------------------------------------------------------
foreach ($old in @('tests/Unit/ExampleTest.php', 'tests/Feature/ExampleTest.php')) {
  if (Test-Path $old) { Remove-Item $old -Force; Write-Host "DEL $old" }
}

# ---------------------------------------------------------------
# 2. phpunit.xml
# ---------------------------------------------------------------
W 'phpunit.xml' @'
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="vendor/autoload.php"
         colors="true"
         cacheDirectory=".phpunit.cache"
         failOnRisky="true"
         failOnWarning="true"
         failOnDeprecation="true"
         failOnNotice="true"
         displayDetailsOnTestsThatTriggerDeprecations="true"
         displayDetailsOnTestsThatTriggerNotices="true"
         displayDetailsOnTestsThatTriggerWarnings="true"
>
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Feature">
            <directory>tests/Feature</directory>
        </testsuite>
    </testsuites>
    <source restrictDeprecations="true" restrictNotices="true" restrictWarnings="true">
        <include>
            <directory>app</directory>
        </include>
    </source>
    <php>
        <env name="APP_ENV" value="testing"/>
        <env name="APP_MAINTENANCE_DRIVER" value="file"/>
        <env name="APP_FORCE_HTTPS" value="false"/>
        <env name="BCRYPT_ROUNDS" value="4"/>
        <env name="CACHE_STORE" value="array"/>
        <env name="DB_CONNECTION" value="pgsql"/>
        <env name="DB_HOST" value="127.0.0.1"/>
        <env name="DB_PORT" value="5432"/>
        <env name="DB_DATABASE" value="pabwe_p8_blog_test"/>
        <env name="DB_USERNAME" value="postgres"/>
        <env name="MAIL_MAILER" value="array"/>
        <env name="OPENAI_API_KEY" value=""/>
        <env name="QUEUE_CONNECTION" value="sync"/>
        <env name="SESSION_DRIVER" value="array"/>
    </php>
</phpunit>
'@

# ---------------------------------------------------------------
# 3. Dasar test
# ---------------------------------------------------------------
W 'tests/TestCase.php' @'
<?php

declare(strict_types=1);

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    /**
     * Pengaman: test tidak boleh berjalan di database aplikasi.
     * Dicek sebelum trait RefreshDatabase sempat menjalankan migrate:fresh.
     */
    protected function refreshApplication(): void
    {
        parent::refreshApplication();

        $default = (string) $this->app['config']->get('database.default');
        $database = (string) $this->app['config']->get("database.connections.{$default}.database");

        if ($default !== 'pgsql' || ! str_ends_with($database, '_test')) {
            throw new RuntimeException(sprintf(
                'Test harus memakai PostgreSQL dengan nama database berakhiran "_test" (sekarang: %s / %s). Periksa phpunit.xml.',
                $default,
                $database,
            ));
        }
    }
}
'@

W 'tests/Support/FakeAiClient.php' @'
<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Features\Ai\Contracts\AiClientInterface;
use RuntimeException;

final class FakeAiClient implements AiClientInterface
{
    /**
     * @var list<array{system: string, user: string}>
     */
    public array $calls = [];

    public function __construct(
        private readonly string $response = '{"articles":[]}',
        private readonly ?RuntimeException $failure = null,
    ) {}

    public function complete(string $systemPrompt, string $userPrompt): string
    {
        $this->calls[] = ['system' => $systemPrompt, 'user' => $userPrompt];

        if ($this->failure !== null) {
            throw $this->failure;
        }

        return $this->response;
    }

    public static function returning(string $response): self
    {
        return new self($response);
    }

    public static function failing(string $message): self
    {
        return new self('', new RuntimeException($message));
    }

    /**
     * @param  list<mixed>  $articles
     */
    public static function withArticles(array $articles): self
    {
        return new self((string) json_encode(['articles' => $articles], JSON_UNESCAPED_UNICODE));
    }
}
'@

W 'tests/Support/BuildsSpreadsheets.php' @'
<?php

declare(strict_types=1);

namespace Tests\Support;

use Illuminate\Http\UploadedFile;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

trait BuildsSpreadsheets
{
    /**
     * @param  list<list<mixed>>  $rows
     */
    protected function xlsxBinary(array $rows): string
    {
        $spreadsheet = new Spreadsheet();
        $spreadsheet->getActiveSheet()->fromArray($rows, null, 'A1', true);

        $path = (string) tempnam(sys_get_temp_dir(), 'blogxlsx');
        (new Xlsx($spreadsheet))->save($path);

        $binary = (string) file_get_contents($path);
        unlink($path);

        return $binary;
    }

    /**
     * @param  list<list<mixed>>  $rows
     */
    protected function xlsxUpload(array $rows, string $name = 'artikel.xlsx'): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, $this->xlsxBinary($rows));
    }
}
'@

# ---------------------------------------------------------------
# 4. Unit: Enum, DTO
# ---------------------------------------------------------------
W 'tests/Unit/PostCategoryTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Enums\PostCategory;
use PHPUnit\Framework\TestCase;

final class PostCategoryTest extends TestCase
{
    public function test_values_lists_every_category(): void
    {
        $this->assertSame(
            ['Teknologi', 'Pendidikan', 'Gaya Hidup', 'Bisnis', 'Opini', 'Umum'],
            PostCategory::values(),
        );
    }

    public function test_every_case_has_a_label(): void
    {
        $expected = [
            'Teknologi' => 'Teknologi & Koding',
            'Pendidikan' => 'Pendidikan & Tutorial',
            'Gaya Hidup' => 'Gaya Hidup & Produktivitas',
            'Bisnis' => 'Bisnis & Karir',
            'Opini' => 'Opini & Pemikiran',
            'Umum' => 'Umum',
        ];

        foreach (PostCategory::cases() as $case) {
            $this->assertSame($expected[$case->value], $case->label());
        }
    }

    public function test_options_pair_value_with_label(): void
    {
        $options = PostCategory::options();

        $this->assertCount(6, $options);
        $this->assertSame(
            ['value' => 'Gaya Hidup', 'label' => 'Gaya Hidup & Produktivitas'],
            $options[2],
        );
    }

    public function test_try_from_accepts_known_values_only(): void
    {
        $this->assertSame(PostCategory::Bisnis, PostCategory::tryFrom('Bisnis'));
        $this->assertNull(PostCategory::tryFrom('Tidak Ada'));
    }
}
'@

W 'tests/Unit/GeneratedPostItemTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Ai\DTO\GeneratedPostItem;
use PHPUnit\Framework\TestCase;

final class GeneratedPostItemTest extends TestCase
{
    public function test_to_array_exposes_all_fields(): void
    {
        $item = new GeneratedPostItem('Judul', 'Teknologi', 'Ringkasan', '## Isi');

        $this->assertSame('Judul', $item->title);
        $this->assertSame([
            'title' => 'Judul',
            'category' => 'Teknologi',
            'excerpt' => 'Ringkasan',
            'content' => '## Isi',
        ], $item->toArray());
    }
}
'@

# ---------------------------------------------------------------
# 5. Unit: Model + Policy
# ---------------------------------------------------------------
W 'tests/Unit/ModelsTest.php' @'
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
'@

W 'tests/Unit/PostPolicyTest.php' @'
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
'@

# ---------------------------------------------------------------
# 6. Unit: Repository
# ---------------------------------------------------------------
W 'tests/Unit/PostRepositoryTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Post\Enums\PostCategory;
use App\Features\Post\Models\Post;
use App\Features\Post\Repositories\PostRepository;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class PostRepositoryTest extends TestCase
{
    use RefreshDatabase;

    private PostRepository $repository;

    protected function setUp(): void
    {
        parent::setUp();

        $this->repository = new PostRepository();
    }

    /**
     * @param  iterable<int, Post>  $posts
     * @return list<string>
     */
    private function titles(iterable $posts): array
    {
        return collect($posts)->pluck('title')->values()->all();
    }

    public function test_public_listing_has_only_published_posts_newest_first(): void
    {
        Post::factory()->create(['title' => 'Lama', 'published_at' => now()->subDays(5)]);
        Post::factory()->create(['title' => 'Baru', 'published_at' => now()]);
        Post::factory()->draft()->create(['title' => 'Draf']);

        $page = $this->repository->paginatePublic(null, null);

        $this->assertSame(2, $page->total());
        $this->assertSame(['Baru', 'Lama'], $this->titles($page->items()));
        $this->assertTrue($page->items()[0]->relationLoaded('user'));
    }

    public function test_public_listing_respects_per_page(): void
    {
        Post::factory()->count(3)->create();

        $page = $this->repository->paginatePublic(null, null, 2);

        $this->assertCount(2, $page->items());
        $this->assertSame(2, $page->lastPage());
    }

    public function test_search_matches_title_case_insensitively(): void
    {
        Post::factory()->create(['title' => 'Belajar Laravel', 'content' => 'isi satu']);
        Post::factory()->create(['title' => 'Belajar React', 'content' => 'isi dua']);

        $page = $this->repository->paginatePublic('laravel', null);

        $this->assertSame(['Belajar Laravel'], $this->titles($page->items()));
    }

    public function test_search_matches_content(): void
    {
        Post::factory()->create(['title' => 'Judul A', 'content' => 'Membahas Eloquent ORM']);
        Post::factory()->create(['title' => 'Judul B', 'content' => 'Hal lainnya']);

        $page = $this->repository->paginatePublic('eloquent', null);

        $this->assertSame(['Judul A'], $this->titles($page->items()));
    }

    public function test_search_treats_percent_literally(): void
    {
        Post::factory()->create(['title' => 'Diskon 50% hari ini', 'content' => 'a']);
        Post::factory()->create(['title' => 'Diskon 500 rupiah', 'content' => 'b']);

        $page = $this->repository->paginatePublic('50%', null);

        $this->assertSame(['Diskon 50% hari ini'], $this->titles($page->items()));
    }

    public function test_search_treats_underscore_literally(): void
    {
        Post::factory()->create(['title' => 'kode_unik', 'content' => 'a']);
        Post::factory()->create(['title' => 'kodeXunik', 'content' => 'b']);

        $page = $this->repository->paginatePublic('kode_unik', null);

        $this->assertSame(['kode_unik'], $this->titles($page->items()));
    }

    public function test_blank_search_is_ignored(): void
    {
        Post::factory()->count(2)->create();

        $this->assertSame(2, $this->repository->paginatePublic('   ', null)->total());
        $this->assertSame(2, $this->repository->paginatePublic(null, null)->total());
    }

    public function test_category_filter_accepts_valid_and_ignores_unknown_values(): void
    {
        Post::factory()->category(PostCategory::Bisnis)->create();
        Post::factory()->category(PostCategory::Opini)->create();

        $bisnis = $this->repository->paginatePublic(null, 'Bisnis');

        $this->assertSame(1, $bisnis->total());
        $this->assertSame('Bisnis', $bisnis->items()[0]->category);
        $this->assertSame(2, $this->repository->paginatePublic(null, 'Tidak Ada')->total());
    }

    public function test_find_published_by_slug(): void
    {
        $published = Post::factory()->create(['slug' => 'terbit']);
        Post::factory()->draft()->create(['slug' => 'draf']);

        $found = $this->repository->findPublishedBySlug('terbit');

        $this->assertNotNull($found);
        $this->assertTrue($found->is($published));
        $this->assertTrue($found->relationLoaded('user'));
        $this->assertNull($this->repository->findPublishedBySlug('draf'));
        $this->assertNull($this->repository->findPublishedBySlug('tidak-ada'));
    }

    public function test_user_listing_contains_only_own_posts_newest_first(): void
    {
        $mine = User::factory()->create();
        $other = User::factory()->create();

        Post::factory()->count(2)->create(['user_id' => $mine->id]);
        Post::factory()->draft()->create(['user_id' => $mine->id, 'title' => 'Draf Terbaru']);
        Post::factory()->create(['user_id' => $other->id]);

        $page = $this->repository->paginateForUser($mine->id, null, null, null);

        $this->assertSame(3, $page->total());
        $this->assertSame('Draf Terbaru', $page->items()[0]->title);
    }

    public function test_user_listing_status_filter(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->draft()->create(['user_id' => $user->id]);

        $this->assertSame(2, $this->repository->paginateForUser($user->id, null, null, 'published')->total());
        $this->assertSame(1, $this->repository->paginateForUser($user->id, null, null, 'draft')->total());
        $this->assertSame(3, $this->repository->paginateForUser($user->id, null, null, 'weird')->total());
    }

    public function test_user_listing_supports_search_and_category(): void
    {
        $user = User::factory()->create();
        Post::factory()->category(PostCategory::Teknologi)->create(['user_id' => $user->id, 'title' => 'Tentang PHP', 'content' => 'x']);
        Post::factory()->category(PostCategory::Umum)->create(['user_id' => $user->id, 'title' => 'Tentang Kopi', 'content' => 'y']);

        $page = $this->repository->paginateForUser($user->id, 'tentang', 'Teknologi', null);

        $this->assertSame(['Tentang PHP'], $this->titles($page->items()));
    }

    public function test_all_listing_includes_drafts_and_loads_author(): void
    {
        Post::factory()->create();
        Post::factory()->draft()->create();

        $page = $this->repository->paginateAll(null, null, null);

        $this->assertSame(2, $page->total());
        $this->assertTrue($page->items()[0]->relationLoaded('user'));
        $this->assertSame(1, $this->repository->paginateAll(null, null, 'draft')->total());
        $this->assertSame(1, $this->repository->paginateAll(null, null, 'published')->total());
    }

    public function test_stats_for_user(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->draft()->create(['user_id' => $user->id]);
        Post::factory()->create();

        $this->assertSame(
            ['total' => 3, 'published' => 2, 'draft' => 1],
            $this->repository->statsForUser($user->id),
        );

        $empty = User::factory()->create();

        $this->assertSame(
            ['total' => 0, 'published' => 0, 'draft' => 0],
            $this->repository->statsForUser($empty->id),
        );
    }

    public function test_export_returns_all_or_per_user_ordered_by_id(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['user_id' => $user->id]);
        Post::factory()->create();

        $all = $this->repository->forExport();

        $this->assertCount(3, $all);
        $this->assertTrue($all->first()->relationLoaded('user'));
        $this->assertTrue($all->first()->id < $all->last()->id);
        $this->assertCount(2, $this->repository->forExport($user->id));
    }

    public function test_create_update_and_delete(): void
    {
        $user = User::factory()->create();

        $post = $this->repository->create([
            'user_id' => $user->id,
            'title' => 'Judul',
            'slug' => 'judul',
            'category' => 'Umum',
            'excerpt' => 'ringkas',
            'content' => 'isi',
            'is_published' => false,
            'published_at' => null,
        ]);

        $this->assertDatabaseHas('posts', ['slug' => 'judul']);

        $updated = $this->repository->update($post, ['title' => 'Judul Baru']);

        $this->assertSame('Judul Baru', $updated->title);
        $this->assertDatabaseHas('posts', ['id' => $post->id, 'title' => 'Judul Baru']);

        $this->repository->delete($post);

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
    }

    public function test_slug_exists_can_ignore_a_post(): void
    {
        $post = Post::factory()->create(['slug' => 'sama']);

        $this->assertTrue($this->repository->slugExists('sama'));
        $this->assertFalse($this->repository->slugExists('sama', $post->id));
        $this->assertTrue($this->repository->slugExists('sama', $post->id + 1));
        $this->assertFalse($this->repository->slugExists('lain'));
    }
}
'@

# ---------------------------------------------------------------
# 7. Unit: OpenAiPostGeneratorService
# ---------------------------------------------------------------
W 'tests/Unit/OpenAiPostGeneratorServiceTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Ai\Services\OpenAiPostGeneratorService;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\FakeAiClient;

final class OpenAiPostGeneratorServiceTest extends TestCase
{
    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function article(array $overrides = []): array
    {
        return array_merge([
            'title' => 'Judul',
            'category' => 'Teknologi',
            'excerpt' => 'Ringkas',
            'content' => '## Isi',
        ], $overrides);
    }

    public function test_generate_maps_articles_into_items(): void
    {
        $client = FakeAiClient::withArticles([
            $this->article(['title' => 'Satu']),
            $this->article(['title' => 'Dua', 'category' => 'Bisnis']),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('Laravel', 2);

        $this->assertCount(2, $items);
        $this->assertSame('Satu', $items[0]->title);
        $this->assertSame('Bisnis', $items[1]->category);
        $this->assertSame('Ringkas', $items[0]->excerpt);
        $this->assertSame('## Isi', $items[0]->content);
    }

    public function test_generate_sends_topic_count_and_category_list(): void
    {
        $client = FakeAiClient::withArticles([$this->article()]);

        (new OpenAiPostGeneratorService($client))->generate('  Laravel  ', 3);

        $this->assertCount(1, $client->calls);
        $this->assertStringContainsString('Buat 3 artikel blog berbeda tentang topik: Laravel', $client->calls[0]['user']);
        $this->assertStringContainsString(
            'Teknologi, Pendidikan, Gaya Hidup, Bisnis, Opini, Umum',
            $client->calls[0]['system'],
        );
    }

    public function test_generate_clamps_the_requested_count(): void
    {
        $client = FakeAiClient::withArticles([$this->article()]);
        $service = new OpenAiPostGeneratorService($client);

        $service->generate('x', 99);
        $service->generate('x', 0);

        $this->assertStringContainsString('Buat 10 artikel', $client->calls[0]['user']);
        $this->assertStringContainsString('Buat 1 artikel', $client->calls[1]['user']);
    }

    public function test_generate_accepts_a_plain_list(): void
    {
        $client = FakeAiClient::returning((string) json_encode([$this->article(['title' => 'Daftar'])]));

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 1);

        $this->assertSame('Daftar', $items[0]->title);
    }

    public function test_generate_strips_markdown_code_fences(): void
    {
        $json = json_encode(['articles' => [$this->article(['title' => 'Berpagar'])]]);
        $client = FakeAiClient::returning("```json\n".$json."\n```");

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 1);

        $this->assertSame('Berpagar', $items[0]->title);
    }

    public function test_unknown_category_falls_back_to_umum_and_match_ignores_case(): void
    {
        $client = FakeAiClient::withArticles([
            $this->article(['category' => 'Astronomi']),
            $this->article(['category' => 'teknologi']),
            $this->article(['category' => null]),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 3);

        $this->assertSame(['Umum', 'Teknologi', 'Umum'], array_map(fn ($item) => $item->category, $items));
    }

    public function test_invalid_entries_are_skipped(): void
    {
        $client = FakeAiClient::withArticles([
            'teks biasa',
            $this->article(['title' => '']),
            $this->article(['content' => '   ']),
            $this->article(['title' => 123]),
            $this->article(['title' => 'Valid']),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 5);

        $this->assertCount(1, $items);
        $this->assertSame('Valid', $items[0]->title);
    }

    public function test_result_is_limited_to_the_requested_count(): void
    {
        $client = FakeAiClient::withArticles([
            $this->article(['title' => 'A']),
            $this->article(['title' => 'B']),
            $this->article(['title' => 'C']),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 2);

        $this->assertSame(['A', 'B'], array_map(fn ($item) => $item->title, $items));
    }

    public function test_long_title_and_excerpt_are_truncated(): void
    {
        $client = FakeAiClient::withArticles([
            $this->article(['title' => str_repeat('a', 300), 'excerpt' => str_repeat('b', 1500)]),
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 1);

        $this->assertSame(255, strlen($items[0]->title));
        $this->assertSame(1000, strlen($items[0]->excerpt));
    }

    public function test_missing_excerpt_becomes_empty_string(): void
    {
        $client = FakeAiClient::withArticles([
            ['title' => 'Tanpa Ringkasan', 'content' => 'isi'],
        ]);

        $items = (new OpenAiPostGeneratorService($client))->generate('x', 1);

        $this->assertSame('', $items[0]->excerpt);
    }

    public function test_invalid_json_raises_a_friendly_error(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Respons AI tidak dapat dibaca');

        (new OpenAiPostGeneratorService(FakeAiClient::returning('bukan json')))->generate('x', 1);
    }

    public function test_scalar_json_raises_a_friendly_error(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Respons AI tidak dapat dibaca');

        (new OpenAiPostGeneratorService(FakeAiClient::returning('5')))->generate('x', 1);
    }

    public function test_empty_article_list_raises_an_error(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('AI tidak menghasilkan artikel');

        (new OpenAiPostGeneratorService(FakeAiClient::withArticles([])))->generate('x', 1);
    }

    public function test_object_without_articles_key_raises_an_error(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('AI tidak menghasilkan artikel');

        (new OpenAiPostGeneratorService(FakeAiClient::returning('{"foo":"bar"}')))->generate('x', 1);
    }

    public function test_client_failure_is_propagated(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Layanan AI sedang gangguan');

        (new OpenAiPostGeneratorService(FakeAiClient::failing('Layanan AI sedang gangguan')))->generate('x', 1);
    }
}
'@

# ---------------------------------------------------------------
# 8. Unit: AppServiceProvider (binding, Policy, HTTPS, pesan validasi, klien OpenAI)
# ---------------------------------------------------------------
W 'tests/Unit/AppServiceProviderTest.php' @'
<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Features\Ai\Contracts\AiClientInterface;
use App\Features\Ai\Services\OpenAiPostGeneratorService;
use App\Features\Post\Contracts\PostRepositoryInterface;
use App\Features\Post\Models\Post;
use App\Features\Post\Policies\PostPolicy;
use App\Features\Post\Repositories\PostRepository;
use App\Providers\AppServiceProvider;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

final class AppServiceProviderTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Http::preventStrayRequests();
    }

    public function test_repository_interface_is_bound(): void
    {
        $this->assertInstanceOf(PostRepository::class, $this->app->make(PostRepositoryInterface::class));
    }

    public function test_ai_client_and_generator_can_be_resolved(): void
    {
        $this->assertInstanceOf(AiClientInterface::class, $this->app->make(AiClientInterface::class));
        $this->assertInstanceOf(OpenAiPostGeneratorService::class, $this->app->make(OpenAiPostGeneratorService::class));
    }

    public function test_post_policy_is_registered(): void
    {
        $this->assertInstanceOf(PostPolicy::class, Gate::getPolicyFor(Post::class));
    }

    public function test_validation_messages_are_in_indonesian(): void
    {
        $this->app->setLocale('id');

        $this->assertSame('Judul wajib diisi.', __('validation.required', ['attribute' => 'Judul']));
        $this->assertSame('Judul maksimal 255 karakter.', __('validation.max.string', ['attribute' => 'Judul', 'max' => 255]));
        $this->assertSame('Judul', __('validation.attributes.title'));
    }

    public function test_https_is_forced_when_enabled(): void
    {
        config(['app.force_https' => true]);

        (new AppServiceProvider($this->app))->boot();

        $this->assertStringStartsWith('https://', url('/artikel'));
    }

    public function test_https_is_not_forced_when_disabled(): void
    {
        config(['app.force_https' => false]);

        (new AppServiceProvider($this->app))->boot();

        $this->assertStringStartsWith('http://', url('/artikel'));
    }

    public function test_openai_client_returns_the_message_content(): void
    {
        config([
            'openai.api_key' => 'sk-test',
            'openai.base_url' => 'https://api.openai.test/v1/',
            'openai.model' => 'gpt-test',
        ]);

        Http::fake([
            'api.openai.test/*' => Http::response(
                ['choices' => [['message' => ['content' => '{"articles":[]}']]]],
                200,
            ),
        ]);

        $content = $this->app->make(AiClientInterface::class)->complete('sistem', 'pengguna');

        $this->assertSame('{"articles":[]}', $content);

        Http::assertSent(function (Request $request): bool {
            return $request->url() === 'https://api.openai.test/v1/chat/completions'
                && $request->hasHeader('Authorization', 'Bearer sk-test')
                && $request['model'] === 'gpt-test'
                && $request['messages'][0]['role'] === 'system'
                && $request['messages'][0]['content'] === 'sistem'
                && $request['messages'][1]['content'] === 'pengguna';
        });
    }

    public function test_openai_client_requires_an_api_key(): void
    {
        foreach (['', null] as $key) {
            config(['openai.api_key' => $key]);

            try {
                $this->app->make(AiClientInterface::class)->complete('a', 'b');
                $this->fail('RuntimeException seharusnya dilempar.');
            } catch (RuntimeException $exception) {
                $this->assertSame('Kunci API OpenAI belum dikonfigurasi.', $exception->getMessage());
            }
        }
    }

    public function test_openai_client_reports_connection_problems(): void
    {
        config(['openai.api_key' => 'sk-test']);
        Http::fake(fn () => throw new ConnectionException('timeout'));

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Tidak dapat terhubung ke layanan AI');

        $this->app->make(AiClientInterface::class)->complete('a', 'b');
    }

    public function test_openai_client_reports_http_errors(): void
    {
        config(['openai.api_key' => 'sk-test']);
        Http::fake(['*' => Http::response('error', 500)]);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('(500)');

        $this->app->make(AiClientInterface::class)->complete('a', 'b');
    }

    public function test_openai_client_rejects_empty_content(): void
    {
        config(['openai.api_key' => 'sk-test']);

        foreach ([
            ['choices' => [['message' => ['content' => '']]]],
            [],
        ] as $payload) {
            Http::fake(['*' => Http::response($payload, 200)]);

            try {
                $this->app->make(AiClientInterface::class)->complete('a', 'b');
                $this->fail('RuntimeException seharusnya dilempar.');
            } catch (RuntimeException $exception) {
                $this->assertStringContainsString('respons kosong', $exception->getMessage());
            }
        }
    }
}
'@

# ---------------------------------------------------------------
# 9. Lint sintaks PHP
# ---------------------------------------------------------------
$phpFiles = @(
  'tests/TestCase.php',
  'tests/Support/FakeAiClient.php',
  'tests/Support/BuildsSpreadsheets.php',
  'tests/Unit/PostCategoryTest.php',
  'tests/Unit/GeneratedPostItemTest.php',
  'tests/Unit/ModelsTest.php',
  'tests/Unit/PostPolicyTest.php',
  'tests/Unit/PostRepositoryTest.php',
  'tests/Unit/OpenAiPostGeneratorServiceTest.php',
  'tests/Unit/AppServiceProviderTest.php'
)
foreach ($f in $phpFiles) {
  php -l $f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "GAGAL: sintaks PHP salah di $f" -ForegroundColor Red
    php -l $f
    exit 1
  }
}
Write-Host "Lint PHP: semua file test valid." -ForegroundColor Green

Write-Host ""
Write-Host "FASE 5a SELESAI." -ForegroundColor Green