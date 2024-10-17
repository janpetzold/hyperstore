#!/bin/bash

# Helper script to run docker image and setting necessary environment variables upfront

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Run the Docker container with the loaded environment variables
docker run --env-file <(env | grep -v '^_') -p 80:80 --network="host" --name hyperstore hyperstore
