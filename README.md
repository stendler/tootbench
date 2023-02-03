![tootbench logo](logo-text.png)

(Image Attribution: adapted from [Midjourney](https://www.midjourney.com) [CC-BY-NC](https://creativecommons.org/licenses/by-nc/4.0/legalcode))

## Requirements

- docker (mandatory)
- docker-compose-plugin

Other requirements - alternatively provided in the gcloud-terraform image (see `make help`):

- make
- openssl
- Apache Maven
- Terraform
- Ansible
- gcloud SDK

## Usage

<details><summary>Setup (for local dev deployment)</summary>

#### Create .env configuration files

Create the `.env.production` file (especially the secrets and keys):

```sh
# generate keys for SECRET_KEY_BASE and OTP_SECRET
docker run -it --rm tootsuite/mastodon bundle exec rake secret
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

</details> 

### Setup for google cloud

#### (optional) Create a docker image for gcloud and terraform

If you don't want to or cannot install terraform and gcloud sdk locally, you can use it through docker:

```sh
docker build -t gcloud-terraform:412 gcloud-terraform
docker run -i --rm --entrypoint /bin/bash -v "$(pwd)/terraform:/home/cloudsdk/terraform" -v gcloud-config-personal:/home/cloudsdk/.config -v gcloud-config-root:/root/.config --name gcloud-terraform -w /home/cloudsdk/plans gcloud-terraform:412
# now you have a shell to run gcloud and terraform commands
```

#### Init

Some scripts make use of the gcloud cli (specifically `gcloud compute ssh-config`), which requires proper login and the
project and zone set:

```sh
export $GCLOUD_PROJECT=cloud-service-benchmarking-22
gcloud auth login
gcloud config set project $GCLOUD_PROJECT
gcloud config set compute/zone europe-west1-b
gcloud auth application-default login
gcloud auth application-default set-quota-project $GCLOUD_PROJECT
```

Generate an SSH key, a root certificate for self-signing, prepare it for bundling it with the client app, 
build the client and generate secrets required for mastodon to be used configured with Terraform and used by Ansible:

```sh
make init
```

#### Deploy single instance

```sh
./scripts/setup-single-instance.sh # setup and deploy everything (including certs)
./scripts/restart-instance.sh # optionally with a terraform resource name to be restarted (default: "instance client")
./scripts/destroy-single-instance.sh # shutdown
```

## TODO
- scenarios:
  - 1x30, 2x15, 3x10
  - 1x10, 2x10, 3x10
  - ~~1x15, 1x15+1x30, 1x10+1x15+1x30~~
- client: parallelize logins (and also follows)
- increase number of threads of the threadpool?
- move docker-compose.yaml from cloud-init to prepare
- client
  - configurable how many users post and how many users listen
  - wait endlessly until shutdown (seems to be the case now already(?))
  - are the intervals really 1 sec each per thread? (should be visible in the logs as well though)
- docker-compose: limit resources / set min reserved

- use vm machine type without bursts: e2-standard-2 should be fine - maybe n2 for 10 gig egress instead of 4
- client vms for load generation instructed from a controller
  - single client vm for now, since its rate limited anyway

Cleanup:
- remove debug logging
- 
- update README: 
  - make usage & requirements
  - adjust tootbench for benchmark runs

## Future ToDos

- add a working email server (proxy like mailslurper) to simulate load produced by sending notification emails?
- monitoring services: move all at once (folder) and specify a custom common target to start them
- monitoring services: awk only relevant lines
- user avatars (differing per user globally) --> load
