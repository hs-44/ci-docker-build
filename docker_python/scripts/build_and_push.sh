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

ACCOUNT_ID=$(aws sts get-caller-identity \
    --query Account \
    --output text)

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION}}"

if [ -z "${REGION}" ]; then
    echo "ERROR: AWS region is not set"
    exit 1
fi

echo "AWS Account ID: ${ACCOUNT_ID}"
echo "AWS Region: ${REGION}"

ECR_REPO_NAME="${DOCKER_IMAGE_NAME}-ecr-repo"

echo "ECR Repository: ${ECR_REPO_NAME}"

if aws ecr describe-repositories \
    --repository-names "${ECR_REPO_NAME}" \
    --region "${REGION}" >/dev/null 2>&1
then
    echo "ECR repository already exists"
else
    echo "Creating ECR repository..."

    aws ecr create-repository \
        --repository-name "${ECR_REPO_NAME}" \
        --region "${REGION}"

    echo "ECR repository created"
fi

IMAGE_TAG="${DOCKER_IMAGE_NAME}-${CODEBUILD_BUILD_NUMBER}"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

FULL_IMAGE_NAME="${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"

echo "Image tag: ${IMAGE_TAG}"
echo "Full image: ${FULL_IMAGE_NAME}"

echo "Logging into ECR..."

aws ecr get-login-password \
    --region "${REGION}" | \
docker login \
    --username AWS \
    --password-stdin "${ECR_REGISTRY}"

echo "ECR login successful"

DOCKER_BUILD_CONTEXT="${CODEBUILD_SRC_DIR}/docker_python"

if [ ! -f "${DOCKER_BUILD_CONTEXT}/Dockerfile" ]; then
    echo "ERROR: Dockerfile not found:"
    echo "${DOCKER_BUILD_CONTEXT}/Dockerfile"
    exit 1
fi

echo "Building Docker image..."

docker build \
    -t "${IMAGE_TAG}" \
    "${DOCKER_BUILD_CONTEXT}"

echo "Docker build successful"

echo "Tagging Docker image..."

docker tag "${IMAGE_TAG}" "${FULL_IMAGE_NAME}"

echo "Docker tag successful"

echo "Pushing Docker image..."

docker push "${FULL_IMAGE_NAME}"

echo "========================================"
echo "Docker Push Successful"
echo "========================================"
echo "Image: ${FULL_IMAGE_NAME}"
