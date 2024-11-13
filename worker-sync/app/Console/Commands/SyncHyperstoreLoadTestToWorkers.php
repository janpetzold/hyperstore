<?php

namespace App\Console\Commands;

use Aws\Ec2\Ec2Client;
use Aws\Ssm\SsmClient;
use Illuminate\Console\Command;

class SyncHyperstoreLoadTestToWorkers extends Command
{
    protected $signature = 'app:sync-hyperstore-load-test-to-workers';

    protected $description = 'Sync loadtest and environment settings to workers';

    protected $ec2Client;
    protected $ssmClient;

    private function getInstanceIds(string $nameSchema, string $region): array {
        $ec2Client = new Ec2Client([
            'region' => $region,
            'version' => 'latest',
            'credentials' => [
                'key' => env('AWS_ACCESS_KEY_ID'),
                'secret' => env('AWS_SECRET_ACCESS_KEY'),
            ],
            'http' => [
                'verify' => false, // Disable SSL - OK for us since this is just a Console script never deployed nowhere
            ],
        ]);
        
        $nameSchema = $nameSchema . "*";
        $result = $ec2Client->describeInstances([
            'Filters' => [
                [
                    'Name' => 'tag:Name',
                    'Values' => [$nameSchema],
                ],
                [
                    'Name' => 'instance-state-name',
                    'Values' => ['running'],
                ],
            ],
        ]);

        $instanceIds = [];
        foreach ($result['Reservations'] as $reservation) {
            foreach ($reservation['Instances'] as $instance) {
                $instanceIds[] = $instance['InstanceId'];
                $this->info('Instance ID: ' . $instance['InstanceId']);
            }
        }

        return $instanceIds;
    }

    private function syncFile(string $instanceId, string $base64Content, string $filePath, string $region) {
        $ssmClient = new SsmClient([
            'region' => $region,
            'version' => 'latest',
            'credentials' => [
                'key' => env('AWS_ACCESS_KEY_ID'),
                'secret' => env('AWS_SECRET_ACCESS_KEY'),
            ],
            'http' => [
                'verify' => false, // Disable SSL - OK for us since this is just a Console script never deployed nowhere
            ],
        ]);

        $command = "echo '$base64Content' | base64 -d > $filePath";

        $ssmClient->sendCommand([
            'DocumentName' => 'AWS-RunShellScript',
            'InstanceIds' => [$instanceId],
            'Parameters' => [
                'commands' => [$command],
            ],
        ]);

        $this->info("File $filePath synced to $instanceId in $region: $region");
    }

    public function handle(){
        $nameSchema = 'Locust'; 
        $regions = ['eu-central-1', 'eu-west-2', 'eu-north-1'];

        // Load files and encode them in base64 - if that is not done I had garbled content on target
        $base64Env = base64_encode(file_get_contents(base_path('tests/.env')));
        $base64Loadtest = base64_encode(file_get_contents(base_path('tests/locustfile.py')));

        foreach ($regions as $region) {
            $instanceIds = $this->getInstanceIds($nameSchema, $region);

            foreach ($instanceIds as $instanceId) {
                $this->syncFile($instanceId, $base64Env, '/home/ubuntu/.env', $region);
                $this->syncFile($instanceId, $base64Loadtest, '/home/ubuntu/locustfile.py', $region);
            }
        }
    }
}
