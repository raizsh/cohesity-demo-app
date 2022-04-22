# Copyright 2022 Cohesity Inc.
#
# This is a simple wrapper around demo_app that restarts it if it
# crashes.

#! /bin/bash

while true; do
  echo "Starting demo-app server ..."
  /opt/demoapp/bin/demo_app_exec $@
  if [ "$?" == "0" ]; then
    echo "Done"
    break
  fi
  echo "Sleeping ..."
  sleep 5
done
