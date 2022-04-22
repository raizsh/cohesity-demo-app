#!/bin/bash
#
# Copyright 2022 Cohesity Inc.
#
# Author: Shubham Raizada
#
# Common functions for app build scripts.

set -o errexit
set -o pipefail
set -x

#------------------------------------------------------------------------------
# Helper function to print command and execute it.
#------------------------------------------------------------------------------
f_exec_cmd() {
  echo "---"
  echo "$@"
  echo
  eval "$@"
}

#------------------------------------------------------------------------------
# Helper function to copy/move docker images to given directory.
#------------------------------------------------------------------------------
f_exec_cmd_mv_image() {
  echo "---"
  echo "sudo mv $@"
  echo
  eval "sudo mv $@"
}

#------------------------------------------------------------------------------
# Helper function to save docker image.
#------------------------------------------------------------------------------
f_exec_cmd_save_image() {
  echo "---"
  echo "sudo docker save $@"
  echo
  eval "sudo docker save $@"
}

#------------------------------------------------------------------------------
# Helper function to copy.
#------------------------------------------------------------------------------
f_exec_cmd_copy() {
  echo "---"
  echo "cp $@"
  echo
  eval "cp $@"
}

#------------------------------------------------------------------------------
# Helper function to build docker images.
#------------------------------------------------------------------------------
f_exec_cmd_build_image() {
  echo "---"
  echo "sudo docker build -t $@"
  echo
  eval "sudo docker build -t $@"
}


#------------------------------------------------------------------------------
# Helper function to run make in other repos with correct environment.
# First arg must be the path of the repo. Following args are the make command.
#------------------------------------------------------------------------------
f_make_cmd() {
  echo "---"
  echo "Running build from $1"
  echo
  cd "$1"
  shift
  # Run the specified make command with the current env make flags unset as
  # they may conflict.
  cmd="$@"
  env --unset MFLAGS --unset MAKEFLAGS $cmd
  cd -
}

#------------------------------------------------------------------------------
# Helper function to initialize environment variables.
#------------------------------------------------------------------------------
f_init_env() {
  default_app_uid=$1
  default_app_version=$2
  INNER_TARBALL_NAME="app.tar.gz"

  CERTS_DIR=`mktemp -d /tmp/certs.XXXXX`
  CERTS_DOWNLOAD_URL="http://artifactory.eng.cohesity.com/artifactory/cohesity-builds-tools/ssl"
  CERTS_CA_BUNDLE_FILE="data-helios-ca-bundle.pem"
  CERTS_KEY_FILE="data-helios-key.pem"
  CERTS_CERT_FILE="data-helios-cert.pem"

  if [ -z "${TC_VERSION}" ]; then
    echo "TC_VERSION not set, taking 6.5"
    TC_VERSION=6.5
  fi

  if [ -z "${DEV_MODE}" ]; then
    echo "DEV_MODE not set, taking default"
    DEV_MODE=false
  fi

  if [ -z "${APP_UID}" ]; then
    APP_UID=${default_app_uid}
    echo "APP_UID not set, taking default"
  fi

  if [ -z "${APP_VERSION}" ]; then
    APP_VERSION=${default_app_version}
    echo "APP_VERSION not set, taking default"
  fi

  # Compute the APP_VERSION_ID
  f_compute_version_id

  # Include the app uid and version for uniqueness. This allows for concurrent
  # app builds.
  TMP_TARBALL_NAME="app${APP_UID}-${APP_VERSION_ID}.tar.gz"

  if [ -z "${PACKAGE_TEMP_DIR}" ]; then
    PACKAGE_TEMP_DIR="$PWD/.pkg"
    echo "PACKAGE_TEMP_DIR not set, taking default"
  fi
  # Suffix the temp directory with the app uid and version for uniqueness.
  # This allows for concurrent app builds.
  PACKAGE_TEMP_DIR="${PACKAGE_TEMP_DIR}-${APP_UID}-${APP_VERSION_ID}"
  YAML_PATH="${PACKAGE_TEMP_DIR}/app.yaml"

  PACKAGE_TARBALL_NAME="app${APP_UID}-${APP_VERSION_ID}.pkg"

  if [ -z "${USE_PRE_QOS_SPEC}" ]; then
    echo "USE_PRE_QOS_SPEC not set, taking default"
    USE_PRE_QOS_SPEC=false
  fi

  if [ -z "${PACKAGE_IMAGE_DIR}" ]; then
    PACKAGE_IMAGE_DIR="$PWD"
  fi

  PRESERVE_DOCKER_IMAGES="false"
  BUILD_TARBALL="true"
  if [ "${DEV_MODE}" == "true" ]; then
    PRESERVE_DOCKER_IMAGES="true"
    BUILD_TARBALL="false"
  fi

  # echo "TOP: " ${TOP}
  echo "CERTS_DIR: " ${CERTS_DIR}
  echo "DEV_MODE: " ${DEV_MODE}
  echo "PACKAGE_TEMP_DIR: " ${PACKAGE_TEMP_DIR}
  echo "APP_UID: ${APP_UID}"
  echo "APP_VERSION: ${APP_VERSION_ID}"
  echo "USE_PRE_QOS_SPEC: " ${USE_PRE_QOS_SPEC}
}

#------------------------------------------------------------------------------
# Helper function to sign and create the package.
#------------------------------------------------------------------------------
function f_common_sign_and_create_package() {
  # Take the inner tarball, sign it with the private key
  # Add the signature, public key, ca certificates
  # and create the final tarball package.

  f_exec_cmd "mkdir -p ${PACKAGE_TEMP_DIR}"

  # downloading certificates.
  f_exec_cmd "wget ${CERTS_DOWNLOAD_URL}/${CERTS_CA_BUNDLE_FILE} --directory-prefix=${CERTS_DIR}"
  f_exec_cmd "wget ${CERTS_DOWNLOAD_URL}/${CERTS_KEY_FILE} --directory-prefix=${CERTS_DIR}"
  f_exec_cmd "wget ${CERTS_DOWNLOAD_URL}/${CERTS_CERT_FILE} --directory-prefix=${CERTS_DIR}"

  # Sign the package
  f_exec_cmd "openssl dgst -sha256 -sign ${CERTS_DIR}/${CERTS_KEY_FILE} \
    -out ${PACKAGE_TEMP_DIR}/app.sig ${TMP_TARBALL_NAME}"

  # Add public key and ca cert bundle.
  f_exec_cmd "cp ${CERTS_DIR}/${CERTS_CERT_FILE} ${PACKAGE_TEMP_DIR}"
  f_exec_cmd "cp ${CERTS_DIR}/${CERTS_CA_BUNDLE_FILE} ${PACKAGE_TEMP_DIR}"

  # removing certificates.
  f_exec_cmd "rm -f ${CERTS_DIR}/${CERTS_CA_BUNDLE_FILE}"
  f_exec_cmd "rm -f ${CERTS_DIR}/${CERTS_KEY_FILE}"
  f_exec_cmd "rm -f ${CERTS_DIR}/${CERTS_CERT_FILE}"

  # Produce the app.id.json.
  json_path="${PACKAGE_TEMP_DIR}/app.id.json"
  cat > ${json_path} <<EOF
{
 "appId": ${APP_UID},
 "version" : ${APP_VERSION_ID}
}
EOF
  f_exec_cmd "cat ${json_path}"

  # Move the inner tar.
  f_exec_cmd "mv ${TMP_TARBALL_NAME} ${PACKAGE_TEMP_DIR}/${INNER_TARBALL_NAME}"

  # Create the images directory.
  f_exec_cmd "mkdir -p ${PACKAGE_IMAGE_DIR}"

  # Now tar and gz the whole directory.
  f_exec_cmd "tar -cvf ${PACKAGE_IMAGE_DIR}/${PACKAGE_TARBALL_NAME} \
    --directory ${PACKAGE_TEMP_DIR} ."

  # Finally, remove the directory.
  f_exec_cmd "rm -rf ${PACKAGE_TEMP_DIR}"
}

#------------------------------------------------------------------------------
# Helper function to create the package.
# TODO: Refactor common code in this method and
#  f_common_sign_and_create_package into a separate method.
#------------------------------------------------------------------------------
function f_common_create_package() {
  # Take the inner tarball and create the final tarball package.

  f_exec_cmd "mkdir -p ${PACKAGE_TEMP_DIR}"

  # Produce the app.id.json.
  json_path="${PACKAGE_TEMP_DIR}/app.id.json"
  cat > ${json_path} <<EOF
{
 "appId": ${APP_UID},
 "version" : ${APP_VERSION_ID}
}
EOF
  f_exec_cmd "cat ${json_path}"

  # Move the inner tar.
  f_exec_cmd "mv ${TMP_TARBALL_NAME} ${PACKAGE_TEMP_DIR}/${INNER_TARBALL_NAME}"

  # Create the images directory.
  f_exec_cmd "mkdir -p ${PACKAGE_IMAGE_DIR}"

  # Now tar and gz the whole directory.
  f_exec_cmd "tar -cvf ${PACKAGE_IMAGE_DIR}/${PACKAGE_TARBALL_NAME} \
    --directory ${PACKAGE_TEMP_DIR} ."

  # Finally, remove the directory.
  f_exec_cmd "rm -rf ${PACKAGE_TEMP_DIR}"
}

#------------------------------------------------------------------------------
# Helper function to get version id.
#------------------------------------------------------------------------------
f_compute_version_id() {
  IFS='.'
  read -a strarr <<< "${APP_VERSION}"
  if [ -z $strarr[0] ]; then
          major_version=0
  else
          major_version=$((10#${strarr[0]} + 0))
  fi

  if [ -z $strarr[1] ]; then
          minor_version=0
  else
          minor_version=$((10#${strarr[1]} + 0))
  fi

  if [ -z $strarr[2] ]; then
          patch_version=0
  else
          patch_version=$((10#${strarr[2]} + 0))
  fi

  version_id=$(( $major_version * 1000000 + $minor_version * 1000 + $patch_version))
  echo "Version id = ", $version_id
  unset IFS

  APP_VERSION_ID="${version_id}"
  APP_MAJOR_VERSION="${major_version}"
  APP_MINOR_VERSION="${minor_version}"
  APP_PATCH_VERSION="${patch_version}"
}
#------------------------------------------------------------------------------
# Helper function to cleanup.
#------------------------------------------------------------------------------
f_common_cleanup() {
  # Delete the temporary package dir and other data.
  f_exec_cmd "rm -rf ${PACKAGE_TEMP_DIR}"
}
