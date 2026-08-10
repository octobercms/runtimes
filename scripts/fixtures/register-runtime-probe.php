<?php

$path = 'routes/console.php';
$text = file_get_contents($path);
$needle = 'Schedule::command("runtime:probe")';

if (!str_contains($text, $needle)) {
    if (!str_contains($text, 'use Illuminate\Support\Facades\Schedule;')) {
        $text = preg_replace(
            "/^<\?php\R/",
            "<?php\n\nuse Illuminate\\Support\\Facades\\Schedule;\n",
            $text,
            1
        );
    }

    $text = rtrim($text) . "\n\nSchedule::command(\"runtime:probe\")->everySecond();\n";
    file_put_contents($path, $text);
}
