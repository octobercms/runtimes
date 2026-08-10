<?php

use App\Jobs\QueueProbeJob;
use Illuminate\Contracts\Console\Kernel;

$base = '/var/www/html';

require $base . '/vendor/autoload.php';

$app = require $base . '/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

QueueProbeJob::dispatch();

echo "QueueProbeJob dispatched\n";
