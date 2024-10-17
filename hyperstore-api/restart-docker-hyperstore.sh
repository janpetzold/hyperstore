#!/bin/bash

# Helper script to apply changes in Dockerfile or other config to purge current container + image and
# run the updated container right away

# Stop the existing hyperstore container
docker stop hyperstore

# Remove the existing hyperstore container
docker rm hyperstore

# Remove the hyperstore image
docker image rm hyperstore

# Build new image
docker build -t hyperstore .

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Run the Docker container with the loaded environment variables
docker run --env-file <(env | grep -v '^_') -p 80:80 --network="host" --name hyperstore hyperstore