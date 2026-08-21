#!/bin/bash

set -e

# This script builds the Docker image and pushes it to Amazon ECR.

echo "Inside build_and_push.sh file"

DOCKER_IMAGE_NAME="$1"

echo "Value of DOCKER_IMAGE_NAME is $DOCKER_IMAGE_NAME"

if [ -z "$DOCKER_IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

# Get the AWS account ID
echo "Getting AWS account ID..."

account=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$account" ]; then
    echo "Unable to get AWS account ID"
    exit 1
fi

echo "AWS Account ID: $account"

# Get AWS region
region="${AWS_REGION:-us-east-1}"

echo "Region value is: $region"

# ECR repository name
ecr_repo_name="${DOCKER_IMAGE_NAME}-ecr-repo"

echo "ECR repository name: $ecr_repo_name"

# Create ECR repository if it doesn't exist
echo "Checking ECR repository..."

if aws ecr describe-repositories \
    --repository-names "$ecr_repo_name" \
    --region "$region" >/dev/null 2>&1
then
    echo "ECR repository already exists: $ecr_repo_name"
else
    echo "ECR repository does not exist. Creating it..."

    aws ecr create-repository \
        --repository-name "$ecr_repo_name" \
        --region "$region"

    echo "ECR repository created successfully"
fi

# Docker image name
image_name="${DOCKER_IMAGE_NAME}-${CODEBUILD_BUILD_NUMBER}"

echo "Local Docker image name: $image_name"

# ECR registry
ecr_registry="${account}.dkr.ecr.${region}.amazonaws.com"

echo "ECR registry: $ecr_registry"

# Login to ECR
echo "Logging in to Amazon ECR..."

aws ecr get-login-password --region "$region" | \
docker login \
    --username AWS \
    --password-stdin "$ecr_registry"

echo "ECR login successful"

# Full ECR image name
fullname="${ecr_registry}/${ecr_repo_name}:${image_name}"

echo "Full image name: $fullname"

# Build Docker image
echo "=========================================="
echo "Docker build started"
echo "=========================================="

docker build \
    -t "$image_name" \
    "$CODEBUILD_SRC_DIR/docker_python/"

echo "Docker build completed successfully"

# Tag Docker image
echo "=========================================="
echo "Tagging Docker image"
echo "=========================================="

docker tag "$image_name" "$fullname"

echo "Docker image tagged successfully"

# Show Docker image
docker images

# Push image to ECR
echo "=========================================="
echo "Docker push started"
echo "=========================================="

docker push "$fullname"

echo "=========================================="
echo "Docker push completed successfully"
echo "=========================================="

echo "Docker image successfully pushed to ECR:"
echo "$fullname"
