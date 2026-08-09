<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class RuntimeProbe extends Command
{
    protected $signature = 'runtime:probe';

    protected $description = 'Probe schedule:work for runtime smoke tests';

    public function handle(): int
    {
        file_put_contents(storage_path('app/scheduler-ran'), (string) time());
        $this->info('runtime probe ok');

        return self::SUCCESS;
    }
}
