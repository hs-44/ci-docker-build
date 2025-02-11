#!/bin/bash
# This script shows how to build the Docker image and push it to ECR for use by SageMaker.

echo "Inside build_and_push.sh file"

# Check if DOCKER_IMAGE_NAME is passed as an argument
DOCKER_IMAGE_NAME=$1

echo "value of DOCKER_IMAGE_NAME is $DOCKER_IMAGE_NAME"

if [ -z "$DOCKER_IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

# Ensure CODEBUILD_SRC_DIR is defined
if [ -z "$CODEBUILD_SRC_DIR" ]; then
    echo "ERROR: CODEBUILD_SRC_DIR is not defined. Exiting."
    exit 1
fi

# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text)

# Check if the AWS CLI command succeeded
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get AWS account number. Exiting."
    exit 255
fi

# Get the region defined in the current configuration (default to us-west-2 if not defined)
region="${AWS_REGION:-us-west-2}"  # Default to 'us-west-2' if AWS_REGION is not set
echo "Region value is: $region"

# Create ECR repository if it does not exist
ecr_repo_name="${DOCKER_IMAGE_NAME}-ecr-repo"
echo "value of ecr_repo_name is $ecr_repo_name"

aws ecr describe-repositories --repository-names "$ecr_repo_name" || \
    aws ecr create-repository --repository-name "$ecr_repo_name"

# Ensure CODEBUILD_BUILD_NUMBER is set for the image tag
if [ -z "$CODEBUILD_BUILD_NUMBER" ]; then
    echo "ERROR: CODEBUILD_BUILD_NUMBER is not defined. Exiting."
    exit 1
fi

image_name="${DOCKER_IMAGE_NAME}-${CODEBUILD_BUILD_NUMBER}"

# Get the login command from ECR and execute docker login
aws ecr get-login-password | docker login --username AWS --password-stdin "${account}.dkr.ecr.${region}.amazonaws.com"

fullname="${account}.dkr.ecr.${region}.amazonaws.com/${ecr_repo_name}:${image_name}"
echo "fullname is $fullname"

# Build the Docker image locally
docker build -t "$image_name" "$CODEBUILD_SRC_DIR/docker_python/"
echo "Docker build complete"

echo "image_name is $image_name"
echo "Tagging of Docker Image in Progress"
docker tag "$image_name" "$fullname"
echo "Tagging of Docker Image Done"

# Display the list of Docker images
docker images

echo "Docker Push in Progress"
docker push "$fullname"
echo "Docker Push Done"

# Check the success of the Docker push operation
if [ $? -ne 0 ]; then
    echo "ERROR: Docker push failed for image $fullname"
    exit 1
else
    echo "SUCCESS: Docker push succeeded for image $fullname"
fi
