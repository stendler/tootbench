## Usage

### Setup (for local dev deployment)

#### Create .env configuration files

Create the `.env.production` file (especially the secrets and keys):

```sh
# generate keys for SECRET_KEY_BASE and OTP_SECRET
docker run -it --rm tootsuite/mastodon rake secret
# generate webpush VAPI key
docker run --rm -i tootsuite/mastodon bash -c "bundle install 1>&2 && bundle exec rake mastodon:webpush:generate_vapid_key"
```

Create a symlink to the new .env-file (ignored by the gitignore within the mastodon folder).

```sh
ln -s ../.env.production mastodon/.env.production
```

#### Generate certificates using [minica]

```sh
# to build minica in docker:
docker build -t minica minica/.
# create a certificate for localhost
docker run --rm -v "$(pwd)/cert:/cert" minica --domains localhost
```

#### Populate DB and pre-compile assets

Run in docker compose to populate docker volumes.

```sh
docker compose -f mastodon/docker-compose.yml run --rm precompile-assets db-migrate
```

#### RUN

```sh
docker compose -f mastodon/docker-compose.yml up
```

### Setup for google cloud

#### (optional) Create a docker image for gcloud and terraform

If you don't want to or cannot install terraform and gcloud sdk locally, you can use it through docker:

```sh
docker build -t gcloud-terraform:412 gcloud-terraform
docker run -i --rm --entrypoint /bin/bash -v "$(pwd)/plans:/home/cloudsdk/plans" -v gcloud-config-personal:/home/cloudsdk/.config -v gcloud-config-root:/root/.config --name gcloud-terraform -w /home/cloudsdk/plans gcloud-terraform:412
# now you have a shell to run gcloud and terraform commands
```

#### Init

```sh
export $GCLOUD_PROJECT=cloud-service-benchmarking-22
gcloud auth login
gcloud config set project $GCLOUD_PROJECT
gcloud config set compute/zone europe-west1-b
gcloud auth application-default login
gcloud auth application-default set-quota-project $GCLOUD_PROJECT
ssh-keygen -f .ssh/id_ed25519 -t ed25519
docker build -t minica minica/. # if not done already
# after running once...
openssl x509 -outform der -in cert/minica.pem -out client/src/main/resources/minica.der

```

#### Deploy single instance

```sh
./scripts/setup-single-instance.sh # setup and deploy everything (including certs)
./scripts/restart-instance.sh # optionally with a terraform resource name to be restarted (default: "instance controller")
./scripts/destroy-single-instance.sh # shutdown
```


## TODO
- metric collection: system stats - vmstat(?) - send metrics directly to controller to avoid disk logging? -> configurable?
  - docker image & container - limit resources
- load generation: selenium (is that even allowed?) -> direct api calls are fine for now 
  - (tootctl? or a programmed tool using a lib or http api request directly)
- scenario configuration: tfvars for machine_type, number of users per instance, number of instances
  - client config: messages per second per user?
- federate
- docker-compose: limit resources / set min reserved
- add a working email server (proxy like mailslurper) to simulate load produced by sending notification emails?

- use vm machine type without bursts: m3-medium (?) - e2-standard-2 should be fine - maybe n2 for 10 gig egress instead of 4
- client vms for load generation instructed from the controller

- slide: show a diagram/architecture

# terraform: client vm & server vm

# ansible? compose
