<?php

$base = '/var/www/html';
$cms = $base . '/storage/framework/cache/cms';
$disabled = $cms . '/disabled.php';
$user = posix_getpwuid(posix_geteuid())['name'] ?? (string) posix_geteuid();

@mkdir($base . '/storage/app', 0777, true);
file_put_contents($base . '/storage/app/cache-warm-user', $user);

if (is_file($disabled)) {
    file_put_contents($base . '/storage/app/cache-warm-stale-present', '1');
}

fwrite(STDERR, "cache-warm artisan stderr user={$user}\n");
echo "cache-warm artisan stdout should be discarded\n";

if (!is_dir($cms)) {
    fwrite(STDERR, "cache/cms directory is missing\n");
    exit(1);
}

file_put_contents($disabled, "<?php return ['warmed' => true];\n");
file_put_contents($cms . '/manifest.php', "<?php return ['warmed' => true];\n");

$logDir = $base . '/storage/logs';
@mkdir($logDir, 0777, true);
file_put_contents($logDir . '/laravel.log', "warmed as {$user}\n", FILE_APPEND);

if (getenv('CACHE_WARM_FAIL') === '1') {
    fwrite(STDERR, "cache-warm artisan forced failure\n");
    exit(1);
}

exit(0);
