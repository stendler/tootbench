#!/usr/bin/env sh

if [ -z "$1" -o -z $GCLOUD_PROJECT ]; then
  GCLOUD_PROJECT=cloud-service-benchmarking-22
fi

if [ -n "$1" ]; then
  GCLOUD_PROJECT="$1"
fi

if seq "$2" 2>/dev/null 1>/dev/null; then
  max_instances="$2"
else
  max_instances=10
fi

ssh-keygen -f .ssh/id_ed25519 -t ed25519
docker build -t minica minica/. # if not done already
docker run --rm -v "$(pwd)/cert:/cert" minica --domains localhost # if not done already to generate the root cert
openssl x509 -outform der -in cert/minica.pem -out client/src/main/resources/minica.der
(cd client && mvn package) # build the app
echo "secrets:" > playbooks/files/secrets.yaml
# repeat as much as maximum parallel instances to be deployed
for i in $(seq $max_instances); do
  echo "Generating instance secrets [$i/$max_instances]"
  ./scripts/secrets.sh >> playbooks/vars/secrets.yaml
done

export $GCLOUD_PROJECT
gcloud auth login
gcloud config set project $GCLOUD_PROJECT
gcloud config set compute/zone europe-west1-b
gcloud auth application-default login
gcloud auth application-default set-quota-project $GCLOUD_PROJECT
