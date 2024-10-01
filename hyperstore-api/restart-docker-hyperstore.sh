#!/bin/bash

# Helper script to apply hcnages in Dockerfile or other config to purge current container + image and
# run the updated container right away

# Stop the existing hyperstore container
docker stop hyperstore

# Remove the existing hyperstore container
docker rm hyperstore

# Remove the hyperstore image
docker image rm hyperstore

# Build new image
docker build -t hyperstore .

# Run a new hyperstore container
docker run -p 80:80 --network="host" --name hyperstore hyperstore