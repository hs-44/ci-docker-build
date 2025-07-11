#!/bin/bash
# set -e
# This script shows how to build the Docker image and push it to ECR to be ready for use
# by SageMaker.

# The argument to this script is the image name. This will be used as the image on the local
#machine and combined with the account and region to form the repository name for ECR.
#Algorithm Name will be the Reposistory Name that is passed as a command line parameter.
echo "Inside build_and_push.sh file"
DOCKER_IMAGE_NAME=$1

echo "value of DOCKER_IMAGE_NAME is $DOCKER_IMAGE_NAME"

if [ "$DOCKER_IMAGE_NAME" == "" ]
then
    echo "Usage: $0 <image-name>"
    exit 1
fi
src_dir=$CODEBUILD_SRC_DIR

# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text)

if [ $? -ne 0 ]
then
    exit 255
fi

# Get the region defined in the current configuration (default to us-west-2 if none defined)
region=$AWS_REGION
echo "Region value is : $region"
# If the repository doesn't exist in ECR, create it.
ecr_repo_name=$DOCKER_IMAGE_NAME"-ecr-repo"
echo "value of ecr_repo_name is $ecr_repo_name"

# || means if the first command succeed the second will never be executed
aws ecr describe-repositories --repository-names ${ecr_repo_name} --region $region || aws ecr create-repository --repository-name ${ecr_repo_name}

image_name=$DOCKER_IMAGE_NAME-$CODEBUILD_BUILD_NUMBER

# Get the login command from ECR and execute docker login
aws ecr get-login-password | docker login --username AWS --password-stdin ${account}.dkr.ecr.${region}.amazonaws.com

fullname="${account}.dkr.ecr.${region}.amazonaws.com/${ecr_repo_name}:$image_name"
echo "fullname is $fullname"
# Build the docker image locally with the image name and then push it to ECR with the full name.

docker build -t ${image_name} $CODEBUILD_SRC_DIR/docker_python/
echo "Docker build after"

echo "image_name is $image_name"
echo "Tagging of Docker Image in Progress"
docker tag ${image_name} ${fullname}
echo "Tagging of Docker Image in Done"
docker images

echo "Docker Push in Progress"
docker push ${fullname}
echo "Docker Push in Done"

if [ $? -ne 0 ]
then
    echo "Docker Push Event did not Succeed with Image ${fullname}"
    exit 1
else
    echo "Docker Push Event is Successful with Image ${fullname}"
fi
