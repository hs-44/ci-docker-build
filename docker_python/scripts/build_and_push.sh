#!/bin/bash
set -ex  # Exit on error and print commands

# This script builds and pushes a Docker image to ECR.

echo "Inside build_and_push.sh file"

DOCKER_IMAGE_NAME=$1

if [ -z "$DOCKER_IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

echo "Value of DOCKER_IMAGE_NAME is: $DOCKER_IMAGE_NAME"

# Define the source directory from CodeBuild
src_dir=$CODEBUILD_SRC_DIR

# Get the AWS account ID
account=$(aws sts get-caller-identity --query Account --output text)

# Get AWS region from environment (fallback to us-west-2 if empty)
region="${AWS_REGION:-us-west-2}"
echo "Region is: $region"

# Set ECR repository name
ecr_repo_name="${DOCKER_IMAGE_NAME}-ecr-repo"
echo "ECR Repo Name is: $ecr_repo_name"

# Create the ECR repo if it doesn't exist
aws ecr describe-repositories --repository-names "$ecr_repo_name" --region "$region" || \
aws ecr create-repository --repository-name "$ecr_repo_name" --region "$region"

# Compose Docker image tag using build number
image_name="${DOCKER_IMAGE_NAME}-${CODEBUILD_BUILD_NUMBER}"

# Authenticate Docker with ECR
aws ecr get-login-password --region "$region" | \
docker login --username AWS --password-stdin "${account}.dkr.ecr.${region}.amazonaws.com"

# Full image name
fullname="${account}.dkr.ecr.${region}.amazonaws.com/${ecr_repo_name}:${image_name}"
echo "Full image name: $fullname"

# Build and tag Docker image
docker build -t "$image_name" "$src_dir/docker_python/"
docker tag "$image_name" "$fullname"

# Push image to ECR
docker push "$fullname"

echo "Docker image pushed successfully: $fullname"
