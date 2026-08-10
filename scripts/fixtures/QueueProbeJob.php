<?php

namespace App\Jobs;

use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class QueueProbeJob implements ShouldQueue
{
    use Queueable;

    public function handle(): void
    {
        file_put_contents(storage_path('app/queue-job-ran'), (string) time());
    }
}
