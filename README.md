# Hyperstore

This is a virtual store that only exists to test scalability & IaC based on Laravel, AWS and Terraform.

## Setup

This project is based on Laravel. To get started do a 

    sudo apt install php php-xml php-curl
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

## Code

The controller was initiated via

    php artisan make:controller HyperController

But just check the codebase.

## Docker image

Before creation make sure to clear everything (see https://stackoverflow.com/a/61953327/675454, https://stackoverflow.com/a/55474102/675454):

    # Optimization
    composer dumpautoload
    php artisan optimize:clear
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

The clients use locust as test framework.

    locust

    aws ssm send-command --document-name "AWS-RunShellScript" --targets "Key=instanceids,Values=i-03d82cc723c65fd85" --parameters 'commands=["locust --headless --users 10 --spawn-rate 1 -H http://3.76.34.171"]'

Check execution at

https://eu-central-1.console.aws.amazon.com/systems-manager/run-command


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

## Todos & Known issues

[x] Add AWS parameter store in terraform using values from .env
[x] Add initial scripted client based on locust
[ ] Client shall not need public IP, SSH or other stuff
[ ] Find way to provision all clients with locustfile.py test file even though they're based on an AMI
[ ] Enhance script to setup fice clients insted of one, spread them across EU region
- setup AWS Parameter Store
[x] use custom Redis to speed up provisioning time
- move everything to a private subnet instead of a public one
- get rid of "static" Elastic IP for Redis for cost reasons (could be fixed via Parameter store)
- automatically set A record to (changing) Fargate IP via script
- .env file is part of Docker image. Seems to be needed for the app key. Remove .env from docker build and externalize these variables via AWS Systems Manager Parameter Store for sake of pricing / simplicity
- fix missing .env file for local docker image: must be there for local testing, must not be there for AWS
- Move Dockerfile out of api dir
- add php-fpm and a "real" web server but make it work in the Docker container
- add resource groups in terraform
- add load balancer to have a static IP
- setup real domain "hyperstore.cc" and link to EU/NAR/SA
- setup TLS
- start client setup with 5 clients from EU via AMI predefined based on Locust