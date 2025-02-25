#!/bin/bash

# Remove existing directories and files
rm -rf python
rm -f python_packages.zip

# Create a new python directory
mkdir python

# Use Docker to build dependencies for arm64
docker run --rm -v "$PWD":/var/task --platform linux/x86_64 public.ecr.aws/sam/build-python3.13:latest \
bash -c "pip install -r requirements.txt -t python/; exit"

# Zip the dependencies
zip -r python_packages.zip python