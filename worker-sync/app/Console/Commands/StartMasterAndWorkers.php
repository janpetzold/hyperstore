<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Aws\Ssm\SsmClient;
use Aws\Ec2\Ec2Client;

class StartMasterAndWorkers extends Command
{
    protected $signature = 'app:start-master-and-workers';
    protected $description = 'Start Locust master and worker nodes across AWS regions';

    private $regions = [
        'eu-central-1',
        'eu-north-1',
        'eu-west-2'
    ];

    public function handle()
    {
        // Start master in eu-central-1 (first instance)
        $ec2Client = new Ec2Client([
            'version' => 'latest',
            'region'  => 'eu-central-1'
        ]);

        // Get instances in eu-central-1
        $instances = $this->getInstances($ec2Client);
        if (empty($instances)) {
            $this->error('No instances found in eu-central-1');
            return 1;
        }

        // Use first instance as master
        $masterId = $instances[0]['InstanceId'];
        $masterIp = $instances[0]['PublicIpAddress'];

        $this->info("Starting master on instance {$masterId} with IP {$masterIp}");

        // Start master
        $ssmClient = new SsmClient([
            'version' => 'latest',
            'region'  => 'eu-central-1'
        ]);

        $this->startMaster($ssmClient, $masterId);

        // Start workers in all regions
        foreach ($this->regions as $region) {
            $ec2Client = new Ec2Client([
                'version' => 'latest',
                'region'  => $region
            ]);

            $ssmClient = new SsmClient([
                'version' => 'latest',
                'region'  => $region
            ]);

            $instances = $this->getInstances($ec2Client);
            
            foreach ($instances as $instance) {
                // Skip the master instance
                if ($region === 'eu-central-1' && $instance['InstanceId'] === $masterId) {
                    continue;
                }

                $this->info("Starting worker on instance {$instance['InstanceId']} in region {$region}");
                $this->startWorker($ssmClient, $instance['InstanceId'], $masterIp);
            }
        }

        $this->info('All nodes started successfully');
        $this->info("Master IP: {$masterIp} - You can now forward port 8089 using:");
        $this->info("aws ssm start-session --target {$masterId} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"8089\"],\"localPortNumber\":[\"8089\"]}'");
        
        return 0;
    }

    private function getInstances(Ec2Client $ec2Client): array
    {
        $result = $ec2Client->describeInstances([
            'Filters' => [
                [
                    'Name' => 'tag:Name',
                    'Values' => ['Locust*']
                ],
                [
                    'Name' => 'instance-state-name',
                    'Values' => ['running']
                ]
            ]
        ]);

        $instances = [];
        foreach ($result['Reservations'] as $reservation) {
            foreach ($reservation['Instances'] as $instance) {
                $instances[] = [
                    'InstanceId' => $instance['InstanceId'],
                    'PublicIpAddress' => $instance['PublicIpAddress']
                ];
            }
        }

        return $instances;
    }

    private function startMaster(SsmClient $ssmClient, string $instanceId): void
    {
        $ssmClient->sendCommand([
            'DocumentName' => 'AWS-RunShellScript',
            'Targets' => [
                [
                    'Key' => 'instanceids',
                    'Values' => [$instanceId]
                ]
            ],
            'Parameters' => [
                'commands' => [
                    'cd /home/ubuntu',
                    'locust --master'
                ],
                'executionTimeout' => ['7200']  // 2 hours
            ],
            'TimeoutSeconds' => 7200  // 2 hours
        ]);
    }

    private function startWorker(SsmClient $ssmClient, string $instanceId, string $masterIp): void
    {
        $ssmClient->sendCommand([
            'DocumentName' => 'AWS-RunShellScript',
            'Targets' => [
                [
                    'Key' => 'instanceids',
                    'Values' => [$instanceId]
                ]
            ],
            'Parameters' => [
                'commands' => [
                    'cd /home/ubuntu',
                    "locust --worker --master-host={$masterIp}"
                ],
                'executionTimeout' => ['7200']  // 2 hours
            ],
            'TimeoutSeconds' => 7200  // 2 hours
        ]);
    }
}