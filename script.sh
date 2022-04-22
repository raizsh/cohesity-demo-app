#!/usr/bin/env bash

# Copyright 2022 Cohesity Inc.
# Author: Shubham Raizada.

# This script helps build the docker files and athena app package for the
# Demo app.
#
# This script takes in these enviroment variables (all optional).
# USE_PRE_QOS_SPEC - true/false (default = false).
# DEV_MODE - true/false (default = false).
# PACKAGE_TEMP_DIR - any directory (default = $PWD/.pkg).
# APP_UID (default = 2)
# APP_VERSION (default = 2)
# ADD_EXTRAS - true/false (default=false)
#
#
# Usage example (any of these could be set):
# APP_UID=2 APP_VERSION=3 USE_PRE_QOS_SPEC=true PACKAGE_TEMP_DIR=/a/b \
#     ./build.sh
#
# For development, use following command. Please note that other env vars
# cannot be used in conjunction with DEV_MODE
# DEV_MODE=true ./build.sh
#
# The above places the docker images for the various components in /tmp/.
# If the argument is skipped or false (default), then the images are
# themselves removed from the docker engine. Otherwise,
# they are preserved (i.e., docker images will list the images).
#
# The application tarball is also placed under the current directory.
#

set -e

#APP Id and APP Version
DEFAULT_APP_UID=14
DEFAULT_APP_VERSION=1.0.11

current_dir=$(dirname `readlink -f $0`)
. $current_dir/common.sh

# Initialize environment variables.
f_init_env ${DEFAULT_APP_UID} ${DEFAULT_APP_VERSION}

# First determine the mode (development vs production) and the Athena YAML
# spec to use (pre QoS vs QoS).

# Image Names
DEMO_APP_IMAGE_NAME="demo_app_server"

# Image Version/Tag
IMAGE_VERSION="latest"
APP_MINOR_VERSION=0
TEMP_DOCKER_IMG_DIR="/tmp"

DEPLOYMENT_TOP_DIR="$current_dir/deployment"

# Dockerfile Directories
DEMO_APP_DEPLOYMENT_DIR="$DEPLOYMENT_TOP_DIR/demo-app"

# Temp Image Path
DEMO_APP_TEMP_IMAGE_PATH="$TEMP_DOCKER_IMG_DIR/$DEMO_APP_IMAGE_NAME:$IMAGE_VERSION"

f_cleanup() {
  f_common_cleanup
}

f_produce_inner_tarball() {
  f_exec_cmd "mkdir -p $PACKAGE_TEMP_DIR"

  # Produce the app.json.
  # Name, description and access requirement of application can be modified
  # based on the application needs
  json_path="$PACKAGE_TEMP_DIR/app.json"
  cat > $json_path <<EOF
{
 "id": ${APP_UID},
 "name" : "Demo-app",
 "version" : ${APP_VERSION_ID},
 "dev_version": "${APP_VERSION}",
 "description" : "Demo-app: Demo app for building applications on Cohesity marketplace",
 "access_requirements" : {
    "read_access" : true,
    "read_write_access" : false,
    "management_access" : true,
    "protected_object_access" : true
 }
}
EOF
  f_exec_cmd "cat $json_path"

  # Copy the athena yaml.
  yaml_path="$PACKAGE_TEMP_DIR/app.yaml"

  # Copy Athena Spec Yaml to $yaml_path
  f_exec_cmd_copy "$DEPLOYMENT_TOP_DIR/athena_spec.yaml $yaml_path"

  f_exec_cmd "cat $yaml_path"

  # Add app icon file.
  f_exec_cmd "cp $current_dir/app_icon.svg $PACKAGE_TEMP_DIR"

  # Copy the images.
  image_dir="$PACKAGE_TEMP_DIR/images"
  f_exec_cmd "mkdir -p $image_dir"

  # Copy or move docker image to $image_dir
  # If application has multiple images we can uses f_exec_cmd_mv_image function
  # multiple times to copy/move images to $image_dir
  f_exec_cmd_mv_image "$DEMO_APP_TEMP_IMAGE_PATH $image_dir"

  f_exec_cmd "sudo chown -R $USER:$USER $PACKAGE_TEMP_DIR"
  f_exec_cmd "ls -larthsR $PACKAGE_TEMP_DIR"

  # Now tar and gz the whole directory.
  # Note that the tarball must be such that it extracts all the files directory
  # to the current directory.
  f_exec_cmd "tar -zcvf $TMP_TARBALL_NAME --directory $PACKAGE_TEMP_DIR ."

  # Finally, remove the directory.
  f_exec_cmd "rm -rf $PACKAGE_TEMP_DIR"
}

f_prepare_base_docker_images() {
  echo "Do nothing"
}

# Clean up everything.
f_cleanup


# Download the base docker container images and load them into the Docker
# cache.
f_prepare_base_docker_images
f_exec_cmd "sudo docker images"

# Build the docker images.
# If application has multiple images we can use f_exec_cmd_build_image function
# multiple times to build different images
f_exec_cmd_build_image "$DEMO_APP_IMAGE_NAME:$IMAGE_VERSION $DEMO_APP_DEPLOYMENT_DIR"


# For debugging: list the docker images.
f_exec_cmd "sudo docker images"

# Now produce the tarball.
if [ "$BUILD_TARBALL" == "true" ]; then
  # Save the docker images.
  # If application has multiple images we can use f_exec_cmd_save_image function
  # multiple times to save different images
  f_exec_cmd_save_image "$DEMO_APP_IMAGE_NAME:$IMAGE_VERSION -o $DEMO_APP_TEMP_IMAGE_PATH"

  # For debugging: List the images produced above.
  # In Current script All Image Name is starting with occ so for listing that image it is demo*
  # Based on your image image replace demo* with your image identifier
  f_exec_cmd "ls -lrths $TEMP_DOCKER_IMG_DIR/demo*"

  f_produce_inner_tarball

  f_common_create_package
fi

# Clean up everything.
f_cleanup
