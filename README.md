# Hyperstore

This is a virtual store that only exists to test scalability & IaC based on Laravel, AWS and Terraform.

## Setup

This project is based on Laravel. To get started do a 

    sudo apt install php php-xml php-curl php-redis php-sqlite3
    sudo apt install composer

Make sure that PHP fileinfo and Redis extension are enabled in `php.ini`:

    extension=fileinfo
    extension=php_redis.dll

To setup the project do

    composer install
    composer create-project laravel/laravel hyperstore-api

This will take a while and shall give you a subdirectory hyperstore-api. Now do this to start the service:

    cd hyperstore-api
    php artisan key:generate
    php artisan serve

## PHP

For some of the advanced features you should use PHP 8.3.x. This is not the default on Ubuntu, therefore do

    sudo add-apt-repository ppa:ondrej/php
    sudo apt update
    sudo apt upgrade
    sudo apt install php-redis php-sqlite3

Check PHP version via

    php --version

## Code

The controller was initiated via

    php artisan make:controller HyperController

But just check the codebase.

## Debug

To use Laravel Debugbar just run

    composer require barryvdh/laravel-debugbar --dev

and set

    APP_DEBUG=true

in `.env`. Also activate the middleware so this also works for JSON in `app/Http/Middleware/Kernel.php`:

    \App\Http\Middleware\AppendDebugbar::class

However the inisghts gained by Debugbar seem limited to me. There is more with Telescope but this requires an SQLite database. Install one via

    sudo apt install sqlite3
    sudo apt install php-sqlite3

On Windows you need to enable

    extension=pdo_sqlite
    extension=sqlite3

in `php.ini`.

And afterwards install telescope for local environment via

    composer require laravel/telescope --dev
    php artisan telescope:install
    php artisan migrate 

Telescope should be available at http://127.0.0.1/telescope then.

## Docker image

Before creation make sure to clear everything (see https://stackoverflow.com/a/61953327/675454, https://stackoverflow.com/a/55474102/675454):

    # TODO: add comment to clear laravel.log 
    php artisan config:clear
    php artisan cache:clear
    # Optimization
    php artisan optimize:clear
    composer dump-autoload --optimize
    # Cache config
    php artisan config:cache
    # Cache routes
    php artisan route:cache

The `Dockerfile`is prepared and an image can be created via

    docker build -t hyperstore .

Run this through

    docker run -p 80:80 --network="host" --name hyperstore hyperstore

The "host" parameter is needed in case you want to access the locally running Redis DB.

Trace logs via

    docker exec -it hyperstore tail -f storage/logs/laravel.log
    docker exec -it hyperstore tail -f /var/log/nginx/access.log
    docker exec -it hyperstore tail -f /var/log/nginx/error.log

Check the enabled routes

    docker exec -it hyperstore php artisan route:list

SSH into the container

     docker exec -it hyperstore sh

## Prepare AWS

    sudo apt install awscli
    aws configure

    # Login to ECR to store Docker image
    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 290562283841.dkr.ecr.eu-central-1.amazonaws.com

    # Create repo
    aws ecr create-repository --repository-name hyperstore-repo --region eu-central-1

    # Tag local image
    docker tag hyperstore:latest 290562283841.dkr.ecr.eu-central-1.amazonaws.com/hyperstore-repo:latest

    # Push image
    docker push 290562283841.dkr.ecr.eu-central-1.amazonaws.com/hyperstore-repo:latest

    # Check that image is actually there
    aws ecr list-images --repository-name hyperstore-repo --region eu-central-1

    # Re-deploy the service with a new image uploaded to ECR
    aws ecs update-service --cluster hyperstore-cluster --service hyperstore-service --force-new-deployment

## IaC

First install Terraform following the [instructions](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli). 

Terraform needs aws credentials. The best way to set this up is via AWS CLI.

    brew install awscli

Then do

    terraform init
    terraform apply

To teardown everything (including history)

    terraform destroy

ECS task execution is enabled so if you need to SSH into the container do

    aws ecs execute-command --cluster hyperstore-cluster --task b12aef02a7a84346bff48ab6487a4ef7 --container hyperstore-app --interactive --command "/bin/bash"

To find out the IP address of the recent task deployment do this - unfortunately this requires 3 steps

    # Get ARN for the latest taks
    aws ecs list-tasks --cluster hyperstore-cluster
    
    # Extract network interface ID
    aws ecs describe-tasks --cluster hyperstore-cluster --tasks d332c5e7942a43a2a437c15138b278e8 | grep eni
    
    # Take the network interface ID to get the public IP of the service
    aws ec2 describe-network-interfaces --network-interface-ids eni-0f842741f2c157970 | grep PublicIp

## Database

We use Redis both for logging activity and the actual "data" that is being processed. For now we
use an EC2-based Redis DB. The issue here is that an Elastic IP is defined here that shall
not change since this would affect the logic, therefore it was removed from terraform handling via

    terraform state rm aws_eip.redis_hyperstore_eip

### Localhost

For local development it is easiest to just install Redis via Linux/WSL

    sudo apt-get install redis-server
    sudo service redis-server start

    # Test via
    redis-cli
    ping

### Server

For now there is just a single DB instance in eu-central-1 that covers all global services.

The Redis DB is set up vi terraform just like all other resources. Publi internet access is not possible, therefore a Bastion jumphost is also set up. To connect to it run

    terraform output

and check the `ssh` command there. This tunnel can also be setup in [Medis](https://getmedis.com/) client.

To use this with `redis-cli` locally port forwarding needs to be enabled. To do this run

    ssh -i bastion_ssh_key.pem -L 6379:eu-redis-cluster.jks2ei.0001.euc1.cache.amazonaws.com:6379 ec2-user@3.72.75.155

Replace Bastion host IP address and Cluster URL accordingly. Leave this command open. Now in another terminal just run

    redis-cli

where you can interact with the remote database.

### Client

The clients use locust as test framework. Locust is pre-installed on the AMI-based VMs (EC2 Nano instance). Essentially this is just an Ubuntu LTS machine with the following setup:

    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get install python3-pip
    pip3 install locust --break-system-packages
    wget https://raw.githubusercontent.com/janpetzold/hyperstore/refs/heads/main/terraform/client/locustfile.py -O /home/ubuntu/locustfile.py
    # Add path to ~/.bashrc
    export PATH="$PATH:/home/ubuntu/.local/bin"
    source ~/.bashrc
    # Then assign proper AMI role AmazonSSMManagedInstanceCore and restart service
    sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service

Amazon SSM agent was available out of the box using the AWS Ubuntu image:

    sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service

The AMI is zone-specific so it needs to be copied to all the regions/zones we care about:

    # Source Frankfurt, Target Stockholm
    aws ec2 copy-image --source-image-id ami-0fab6653f0bd437c0 --source-region eu-central-1 --region eu-north-1 --name "Hyperstore Locust Client" --description "Locust client AMI for benchmarking Hyperstore for eu-north-1"
    # Source Frankfurt, Target London
    aws ec2 copy-image --source-image-id ami-0fab6653f0bd437c0 --source-region eu-central-1 --region eu-west-2 --name "Hyperstore Locust Client" --description "Locust client AMI for benchmarking Hyperstore for eu-west-2"

For now the AMI IDs were as follows

eu-central-1: ami-0fab6653f0bd437c0
eu-north-1: ami-07770aed8130589ff
eu-west-2: ami-0a63027f8a02ac374

I also tried `user_data` scripts but this was pretty unreliable so I went with AMIs.

To run the "default" load test just the host needs to be supplied via AWS SSM like this:

    # Frankfurt node as master 
    aws ssm send-command --region eu-central-1 --document-name "AWS-RunShellScript" --targets "Key=instanceids,Values=i-0d58a8a61174121c1" --parameters 'commands=["cd /home/ubuntu", "locust --master"]'

    # London is worker #1
    aws ssm send-command --region eu-west-2 --document-name "AWS-RunShellScript" --targets "Key=instanceids,Values=i-06590cbc8df5bda27" --parameters 'commands=["cd /home/ubuntu", "locust --worker --master-host=3.75.85.87"]'

    # Stockholm is worker #2
    aws ssm send-command --region eu-north-1 --document-name "AWS-RunShellScript" --targets "Key=instanceids,Values=i-0be0cba45a6e15e08" --parameters 'commands=["cd /home/ubuntu", "locust --worker --master-host=3.75.85.87"]'

Check execution at

https://eu-central-1.console.aws.amazon.com/systems-manager/run-command

#### Master / Slave and UI

By default Locust offers a UI at port 8089 but we don't need to open this one since it would be publically available. Instead fo this we forward the port to our local machine:

    aws ssm start-session --target i-0d58a8a61174121c1 --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["8089"],"localPortNumber":["8089"]}'

and can open the UI then via

http://localhost:8089

In there you can set up the actual load test parameters (number of users, spawn rate, duration etc.). You will end up with something like this

![Locust sample view](images/locust-sample.png)

instance_id_eu_central_1 = "i-0b35666114424c89a"
instance_id_eu_north_1 = "i-03ad18ce2f9efbdd2"
instance_id_eu_west_2 = "i-026dfce053c37f11e"
public_ip_eu_central_1 = "3.73.132.210"
public_ip_eu_north_1 = "16.170.163.218"
public_ip_eu_west_2 = "35.177.215.178"

#### Load test update

Now it may be desired to replace the deafult load script with a custom one. See `locustfile.py` on what is currently used. To replace that without opening another port SSM can also be used, it is not very elegant but essentially we encode the file to Base64 here and "upload" it via echo command which works reliably (at least whenf ile is in kByte range).

    base64_loadtest=$(base64 -w 0 locustfile.py)
    echo $base64_loadtest

    aws ssm send-command --instance-ids "i-0f2c1281ce6b4f466" --document-name "AWS-RunShellScript" --parameters "commands=[\"echo '$base64_loadtest' | base64 -d > /home/ubuntu/locustfile.py\"]"  --output text

Make sure to execute this in the directory where `locustfile.py` is.

## Debugging

Prepare debugging via

    pecl install xdebug

Also/alternatively check the guidelines from https://xdebug.org/wizard

I had a .vscode/launch.json with the following content:

    {
        "version": "0.2.0",
        "configurations": [
        {
            "name": "Listen for Xdebug",
                "type": "php",
            "request": "launch",
            "port": 9003
        }
        ]
    }

And I needed to update php.ini for debugging to work (place this right at the beginning):

    xdebug.mode = debug
    xdebug.start_with_request = yes
    xdebug.client_port = 9003
    xdebug.client_host = "127.0.0.1"

Then just start "Listen for XDebug" in VSCode Run & Debug menu. Install the PHPUnit and PHP Debug extensions beforehand.

## Octane

To speed up the server [Octane](https://laravel.com/docs/11.x/octane#) is used with the [FrankenPHP](https://frankenphp.dev/) server. The impact is quite massive, especially subsequent requests to the same endpoint get a response in less than 50ms (including Redis query) on Fargate (~100ms for local development on Docker or Ubuntu) compared to 400ms for the same request using unoptimized `php artisan serve`.

FrankenPHP only works on Mac or Linux, so on Windows you have to use WSL. Setup via

    composer require laravel/octane
    php artisan octane:install

Create a `Caddyfile` and you can serve the application just like this

    php artisan octane:start --server=frankenphp

For the Docker image the base of [dunglas/frankenphp](https://hub.docker.com/r/dunglas/frankenphp) was used.

## Domain

The domain hyperstore.cc was configured in Cloudflare with he following settings:

- CNAME mapped to AWS NLB DNS
- SSL Mode is "Flexible"
- SSL Edge Certificates set to "Always use HTTPS"

Also I added a WAF rule to block http traffic (field SSL/HTTPS to "off" and then block).

# OAuth2

Based on recent recommendation we want to use the "client_credentials" approach for API authentication. To do this we use Passport. Set this up via

    composer require laravel/passport
    php artisan migrate
    php artisan passport:install --uuids
    php artisan passport:client --personal

This will result in a client ID/secret combination. We don't really have test users for now so just generate a valid access token using

    curl --location 'http://127.0.0.1:8000/oauth/token' --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=client_credentials' --data-urlencode 'client_id=CLIENT-ID' --data-urlencode 'client_secret=CLIENT-SECRET' --data-urlencode 'scope=read'

To change stock just request a token using the "stock" scope, the default "read" scope won't suffice here.

## Performance history
Over time different changes were applied with an impact on E2E performance. This is summarized here. Baseline is always the `/api/hyper` get call to retrieve the current amount of hyper.

| Action / Change | Environment | Response time |
| --- | --- | --- |
| Baseline, no optimization (`php artisan serve`) | Ubuntu (WSL) | 700ms | 
| Baseline, no optimization (`php artisan serve`) | Fargate | 500ms | 
| Optimized/removed Laravel middleware | Ubuntu (WSL) | 680ms | 
| Switch to FrankenPHP | Fargate | 50ms | 
| Add HTTPS via Cloudflare | Fargate | 55ms | 
| Protect API via Access token | Fargate | ? | 

## Todos & Known issues

[x] Add AWS parameter store in terraform using values from .env
[x] Add initial scripted client based on locust
[x] Client shall not need public IP, SSH or other stuff > Public IP and Subnet are indeed needed for SSM, SSH is not
[x] Find way to provision all clients with locustfile.py test file even though they're based on an AMI
[x] start client setup with 3 clients from EU via AMI predefined based on Locust
[x] Update AMI so we can use a proper locust version 2.3*
[x] setup Locust Master/Slave and read actual data via UI / file
[ ] Modify locustfile.py so we have tests that actually make sense
[x] Improve Redis DB connection, figure out how to measure this (Debugbar, Telescope)
[ ] Find/add artisan script to switch environments
[ ] Re-establish SSH access to Redis
[ ] Add IdP for token-based authentication
[x] Add Octane for high-performance PHP serving
[ ] setup AWS Parameter Store
[ ] Automate setting of Cloudflare CNAME record to NLB DNS name via terraform
[x] use custom Redis to speed up provisioning time
[x] move everything to a private subnet instead of a public one
[x] Improve DB performance (400ms is way too much) > Octane and logger optimization
[ ] get rid of "static" Elastic IP for Redis for cost reasons (could be fixed via Parameter store)
[ ] Generate system architecture based on Terraform files
[ ] automatically set A record to (changing) Fargate IP via script
[ ] .env file is part of Docker image. Seems to be needed for the app key. Remove .env from docker build and externalize these variables via AWS Systems Manager Parameter Store for sake of pricing / simplicity
[ ] fix missing .env file for local docker image: must be there for local testing, must not be there for AWS
[ ] Move Dockerfile out of api dir
[-] add php-fpm and a "real" web server but make it work in the Docker container
[ ] add resource groups in terraform
[x] add load balancer to have a static IP
[ ] setup real domain "hyperstore.cc" and link to EU/NAR/SA
[x] setup TLS
[ ] Authenticate with test users instead of static client ID / client secret
[ ] User actual Personal access tokens
[ ] Refactor terraform structure with modules/scripts