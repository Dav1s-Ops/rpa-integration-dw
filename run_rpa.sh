#!/bin/bash

# Exit immediately if any command fails
set -e

# Function to clean up the Docker image
cleanup() {
  echo -e "\n\033[1;33m[INFO]\033[0m Cleaned up Docker image..."
  docker rmi rpa_integration_image || echo -e "\033[1;31m[WARNING]\033[0m Image already removed or not found."
}

# Handle SIGINT (CTRL+C) gracefully
trap "echo -e '\n\033[1;34m[INFO]\033[0m Gracefully exiting... (•‿•)'; exit 0" INT
trap cleanup EXIT

# Building the Docker container
echo -e "\033[1;32m[STEP 1/3]\033[0m Building Docker container..."
docker build -t rpa_integration_image .

# Running the Docker container
echo -e "\033[1;32m[STEP 2/3]\033[0m Running container... Press CTRL+C to stop."
docker run --rm -it rpa_integration_image

# Post-run message
echo -e "\033[1;32m[STEP 3/3]\033[0m Container run completed! 🎉"