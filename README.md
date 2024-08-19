# Hyperstore

This is a virtual store that only exists to test scalability & IaC based on Laravel, AWS and Terraform.

## Setup

This project is based on Laravel. To get started do a 

    sudo apt install php php-xml php-curl
    sudo apt install composer

To setup the project do

    composer create-project laravel/laravel hyperstore-api

This will take a while and shall give you a subdirectory hyperstore-api. Now do this to start the service:

    cd hyperstore-api
    php artisan key:generate
    php artisan serve

## Code

The controller was built via

    php artisan make:controller HyperController

But just check the codebase.

## Docker image

Before creation make sure to clear everything (see https://stackoverflow.com/a/61953327/675454, https://stackoverflow.com/a/55474102/675454):

    composer dumpautoload
    php artisan optimize:clear

The `Dockerfile`is prepared and an image can be created via

    docker build -t hyperstore .

Run this through

    docker run -p 8000:80 --name hyperstore -v $(pwd):/var/www/html -e APP_ENV=production -e APP_DEBUG=false -e LOG_LEVEL=error hyperstore

Trace logs via

    docker exec -it hyperstore tail -f storage/logs/laravel.log
    docker exec -it hyperstore tail -f /var/log/nginx/access.log
    docker exec -it hyperstore tail -f /var/log/nginx/error.log

Check the enabled routes

    docker exec -it hyperstore php artisan route:list

SSH into the container

     docker exec -it hyperstore sh

## Known issues

- Request handling takes very long in local environment (2-5s). How to fix that?
- .env file is part of Docker image. Seems to be needed for the app key. Challenge that.
- Move Dockerfile out of api dir