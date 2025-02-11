#!/bin/bash
# set -e

echo "Inside build_and_push.sh file"
DOCKER_IMAGE_NAME=$1

# Check if image name is provided
if [ -z "$DOCKER_IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

echo "value of DOCKER_IMAGE_NAME is $DOCKER_IMAGE_NAME"

# Ensure environment variables are set
if [ -z "$CODEBUILD_SRC_DIR" ]; then
    echo "CODEBUILD_SRC_DIR is not set."
    exit 1
fi
if [ -z "$AWS_REGION" ]; then
    echo "AWS_REGION is not set."
    exit 1
fi

src_dir=$CODEBUILD_SRC_DIR

# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text)

if [ $? -ne 0 ]; then
    echo "Failed to get AWS account information."
    exit 255
fi

# Get region value
region=$AWS_REGION
echo "Region value is : $region"

# Prepare the ECR repository name
ecr_repo_name="${DOCKER_IMAGE_NAME}-ecr-repo"
echo "value of ecr_repo_name is $ecr_repo_name"

# Create the repository if it doesn't exist
aws ecr describe-repositories --repository-names ${ecr_repo_name} || aws ecr create-repository --repository-name ${ecr_repo_name}

if [ $? -ne 0 ]; then
    echo "Failed to describe or create the repository ${ecr_repo_name}."
    exit 1
fi

# Build the image name
image_name="${DOCKER_IMAGE_NAME}-${CODEBUILD_BUILD_NUMBER:-latest}"

# Get the login command from ECR and execute docker login
aws ecr get-login-password | docker login --username AWS --password-stdin ${account}.dkr.ecr.${region}.amazonaws.com

fullname="${account}.dkr.ecr.${region}.amazonaws.com/${ecr_repo_name}:${image_name}"
echo "fullname is $fullname"

# Ensure Docker is installed
command -v docker >/dev/null 2>&1 || { echo "Docker is not installed. Aborting."; exit 1; }

# Build the docker image locally with the image name and then push it to ECR with the full name
docker build -t ${image_name} $CODEBUILD_SRC_DIR/docker_python/
if [ $? -ne 0 ]; then
    echo "Docker build failed."
    exit 1
fi

echo "image_name is $image_name"
echo "Tagging of Docker Image in Progress"
docker tag ${image_name} ${fullname}
if [ $? -ne 0 ]; then
    echo "Docker tagging failed."
    exit 1
fi
echo "Tagging of Docker Image is Done"
docker images

echo "Docker Push in Progress"
docker push ${fullname}
if [ $? -ne 0 ]; then
    echo "Docker Push Event did not Succeed with Image ${fullname}"
    exit 1
else
    echo "Docker Push Event is Successful with Image ${fullname}"
fi
