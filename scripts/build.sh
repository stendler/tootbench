#!/usr/bin/env sh

# if running inside docker: to be able to mount a volume from the host
if [ -z "$HOST_VOLUME_MOUNT" ]; then
  HOST_VOLUME_MOUNT="$(pwd)"
  echo "No HOST_VOLUME_MOUNT set. Assuming running on the host and the following directory is accessible by the docker daemon: $HOST_VOLUME_MOUNT"
fi

if [ -z "$MVN" ]; then
  if which mvn; then
    MVN=$(which mvn)
  else
    MVN="docker run -it --rm -v "$HOST_VOLUME_MOUNT"/client:/usr/src/client -w /usr/src/client maven:3.8-eclipse-temurin-19-alpine mvn"
  fi
fi

(cd client && $MVN package) # build the app
