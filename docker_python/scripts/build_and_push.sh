#!/bin/bash

set -e

echo "========================================"
echo "Inside build_and_push.sh"
echo "========================================"

DOCKER_IMAGE_NAME="$1"

echo "Value of DOCKER_IMAGE_NAME is: $DOCKER_IMAGE_NAME"

if [ -z "$DOCKER_IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

# Get AWS account ID
echo "Getting AWS account ID..."

ACCOUNT=$(aws sts get-caller-identity \
    --query Account \
    --output text)

echo "AWS Account: $ACCOUNT"

# Get AWS region
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION}}"

if [ -z "$REGION" ]; then
    echo "ERROR: AWS region is not set"
    exit 1
fi

echo "AWS Region: $REGION"

# ECR repository name
ECR_REPO_NAME="${DOCKER_IMAGE_NAME}-ecr-repo"

echo "ECR Repository: $ECR_REPO_NAME"

# Create ECR repository if it doesn't exist
echo "Checking ECR repository..."

if aws ecr describe-repositories \
    --repository-names "$ECR_REPO_NAME" \
    --region "$REGION" > /dev/null 2>&1
then
    echo "ECR repository already exists."
else
    echo "ECR repository does not exist. Creating it..."

    aws ecr create-repository \
        --repository-name "$ECR_REPO_NAME" \
        --region "$REGION"

    echo "ECR repository created."
fi

# Docker image tag
IMAGE_NAME="${DOCKER_IMAGE_NAME}-${CODEBUILD_BUILD_NUMBER}"

echo "Local Docker image: $IMAGE_NAME"

# ECR registry
ECR_REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

FULL_IMAGE_NAME="${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_NAME}"

echo "Full ECR image name:"
echo "$FULL_IMAGE_NAME"

# Login to ECR
echo "========================================"
echo "Logging into Amazon ECR"
echo "========================================"

aws ecr get-login-password --region "$REGION" | \
    docker login \
        --username AWS \
        --password-stdin "$ECR_REGISTRY"

echo "ECR login successful."

# Build Docker image
echo "========================================"
echo "Building Docker image"
echo "========================================"

docker build \
    -t "$IMAGE_NAME" \
    "$CODEBUILD_SRC_DIR/docker_python/"

echo "Docker build successful."

# Tag Docker image
echo "========================================"
echo "Tagging Docker image"
echo "========================================"

docker tag "$IMAGE_NAME" "$FULL_IMAGE_NAME"

echo "Docker image tagged:"
echo "$FULL_IMAGE_NAME"

# Show image
docker images

# Push image
echo "========================================"
echo "Pushing Docker image to ECR"
echo "========================================"

docker push "$FULL_IMAGE_NAME"

echo "========================================"
echo "Docker push successful!"
echo "========================================"
echo "Image:"
echo "$FULL_IMAGE_NAME"
echo "========================================"
