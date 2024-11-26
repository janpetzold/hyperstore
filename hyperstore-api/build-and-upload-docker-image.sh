#!/bin/bash

# Helper script to remove previous Hyperstore container & image, clean the environment, build
# a new image and upload it to AWS ECR

# Stop the existing hyperstore container and remove image
docker stop hyperstore
docker rm hyperstore
docker image rm hyperstore

# Cleanup environment
#php artisan config:clear
#php artisan cache:clear
#php artisan route:clear
#php artisan optimize:clear
composer dump-autoload --optimize
php artisan config:cache
php artisan route:cache

# Build new image and tag it
docker build -t hyperstore .
docker tag hyperstore:latest 290562283841.dkr.ecr.eu-central-1.amazonaws.com/hyperstore-repo:latest

# Run it
# docker run -p 80:80 --network="host" --env-file .env --name hyperstore hyperstore

# Upload to ECR
#aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 290562283841.dkr.ecr.eu-central-1.amazonaws.com
#docker push 290562283841.dkr.ecr.eu-central-1.amazonaws.com/hyperstore-repo:latest

# Restart ECS service
#aws ecs update-service --cluster hyperstore-cluster --service hyperstore-service --force-new-deployment