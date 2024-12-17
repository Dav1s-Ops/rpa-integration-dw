#!/bin/bash

# Exit immediately if any command fails
set -e

# Flag to prevent double cleanup
cleanup_done=false

# Function to clean up the Docker container
cleanup() {
  if [ "$cleanup_done" = false ]; then
    echo -e "\n\033[1;33m[INFO]\033[0m Stopping and removing Docker Compose services and images..."
    docker compose down --rmi local || echo -e "\033[1;31m[WARNING]\033[0m Services already stopped or not found."
    cleanup_done=true
  fi
}

# Handle SIGINT (CTRL+C) gracefully
trap "echo -e '\n\033[1;34m[INFO]\033[0m Gracefully exiting... (•‿•)'; cleanup; exit 0" INT
trap cleanup EXIT

# Building and running the Docker Compose services
echo -e "\033[1;32m[STEP 1/2]\033[0m Building and running Docker Compose services..."
docker compose up --build --remove-orphans

# Post-run message
echo -e "\033[1;32m[STEP 2/2]\033[0m Docker Compose services stopped!"
