#!/bin/bash

set -e

echo "========================================"
echo "Inside build_and_push.sh"
echo "========================================"

DOCKER_IMAGE_NAME="$1"

echo "Value of DOCKER_IMAGE_NAME is: ${DOCKER_IMAGE_NAME}"

if [ -z "${DOCKER_IMAGE_NAME}" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

# AWS account ID
echo "Getting AWS Account ID..."

ACCOUNT_ID=$(aws sts get-caller-identity \
    --query Account \
    --output text)

echo "AWS Account ID: ${ACCOUNT_ID}"

# AWS region
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION}}"

if [ -z "${REGION}" ]; then
    echo "ERROR: AWS region is not set."
    exit 1
fi

echo "AWS Region: ${REGION}"

# ECR repository name
ECR_REPO_NAME="${DOCKER_IMAGE_NAME}-ecr-repo"

echo "ECR Repository: ${ECR_REPO_NAME}"

# Check if ECR repository exists
if aws ecr describe-repositories \
    --repository-names "${ECR_REPO_NAME}" \
    --region "${REGION}" >/dev/null 2>&1
then
    echo "ECR repository already exists."
else
    echo "ECR repository does not exist. Creating it..."

    aws ecr create-repository \
        --repository-name "${ECR_REPO_NAME}" \
        --region "${REGION}"

    echo "ECR repository created successfully."
fi

# Docker image tag
IMAGE_TAG="${DOCKER_IMAGE_NAME}-${CODEBUILD_BUILD_NUMBER}"

echo "Docker Image Tag: ${IMAGE_TAG}"

# ECR registry
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "ECR Registry: ${ECR_REGISTRY}"

# Login to ECR
echo "Logging into Amazon ECR..."

aws ecr get-login-password \
    --region "${REGION}" | \
docker login \
    --username AWS \
    --password-stdin "${ECR_REGISTRY}"

echo "ECR login successful."

# Full ECR image name
FULL_IMAGE_NAME="${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"

echo "Full Docker Image Name:"
echo "${FULL_IMAGE_NAME}"

# Docker build context
DOCKER_BUILD_CONTEXT="${CODEBUILD_SRC_DIR}/docker_python"

echo "Docker Build Context:"
echo "${DOCKER_BUILD_CONTEXT}"

# Verify Dockerfile exists
if [ ! -f "${DOCKER_BUILD_CONTEXT}/Dockerfile" ]; then
    echo "ERROR: Dockerfile not found at:"
    echo "${DOCKER_BUILD_CONTEXT}/Dockerfile"
    exit 1
fi

# Build Docker image
echo "========================================"
echo "Docker Build Started"
echo "========================================"

docker build \
    -t "${IMAGE_TAG}" \
    "${DOCKER_BUILD_CONTEXT}"

echo "Docker build completed successfully."

# Tag image
echo "========================================"
echo "Docker Tag Started"
echo "========================================"

docker tag \
    "${IMAGE_TAG}" \
    "${FULL_IMAGE_NAME}"

echo "Docker tag completed successfully."

# Display images
echo "Docker images:"
docker images

# Push image
echo "========================================"
echo "Docker Push Started"
echo "========================================"

docker push "${FULL_IMAGE_NAME}"

echo "========================================"
echo "Docker Push Successful"
echo "========================================"
echo "Image: ${FULL_IMAGE_NAME}"
echo "========================================"
