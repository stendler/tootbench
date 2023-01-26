#!/usr/bin/env sh

# if running inside docker: to be able to mount a volume from the host
if [ -z "$HOST_VOLUME_MOUNT" ]; then
  HOST_VOLUME_MOUNT="$(pwd)"
  echo 1>2 "No HOST_VOLUME_MOUNT set. Assuming running on the host and the following directory is accessible by the docker daemon: $HOST_VOLUME_MOUNT"
fi

if [ -z "$MVN" ]; then
  if which mvn; then
    (cd client && mvn package)
  else
    (cd client && docker run -it --rm -v "${HOST_VOLUME_MOUNT}/client:/usr/src/client" -v maven-cache:/root/.m2 -w /usr/src/client maven:3.8-eclipse-temurin-19-alpine mvn package)
  fi
fi
