#!/usr/bin/env sh

if seq "$1" 2>/dev/null 1>/dev/null; then
  max_instances="$1"
else
  max_instances=10
fi

# if running inside docker: to be able to mount a volume from the host
if [ -z "$HOST_VOLUME_MOUNT" ]; then
  HOST_VOLUME_MOUNT="$(pwd)"
  echo "No HOST_VOLUME_MOUNT set. Assuming running on the host and the following directory is accessible by the docker daemon: $HOST_VOLUME_MOUNT"
fi

ssh-keygen -f .ssh/id_ed25519 -t ed25519
docker build -t minica minica/. # if not done already
docker run --rm -v "$HOST_VOLUME_MOUNT/cert:/cert" minica --domains localhost # if not done already to generate the root cert
openssl x509 -outform der -in cert/minica.pem -out client/src/main/resources/minica.der
./scripts/build.sh
echo "secrets:" > terraform/secrets.yaml
# repeat as much as maximum parallel instances to be deployed
for i in $(seq $max_instances); do
  echo "Generating instance secrets [$i/$max_instances]"
  ./scripts/secrets.sh >> terraform/secrets.yaml
done
terraform -chdir=terraform init
