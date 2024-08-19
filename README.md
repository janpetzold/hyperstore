# Hyperstore

This is a virtual store that only exists to test scalability & IaC.

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

Build the controller via

    php artisan make:controller HyperController