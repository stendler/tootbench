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

For analysis:

- python3
- poetry

## Usage

<details><summary>Setup (for local dev deployment)</summary>

> ⚠ **NOTE:** The Dockerfile was moved/renamed and may currently **not** be fully functional. This was only used as a playground.

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

#### Manual deployment

(see `make help` for available scenarios and fulfilled requirement)

```sh
make scenario=debug_multi setup prepare start
# stop and retrieve log files:
make scenario=debug_multi stop collect
# to shutdown all resources:
make destroy
```

#### Tootbench CLI tool

In the project root directory, the following command runs the benchmarked scenarios for a client duration of 20 minutes and with 5 repetitions:

```sh
./tootbench -n 5 --runtime 1200 -c  6core-6GB_25sidekiq_5.5s_interval_20min 3x10 2x15 2x10 1x10 1x30
```

A summary of the configuration will be shown and needs to be confirmed.
After that, the tool will run all everything automatically, even posting progress notifications via ntfy.sh and retrying if a run failed somewhere.

After all runs it will run the `./analysis/preprocess.sh` script automatically on the new files.

### Analysis

Requires Python3 and poetry (not available in the gcloud-terraform container).

Install dependencies via poetry in the `analysis` directory, if not done already: `poetry install`.

Within the `analysis` directory run `./picasso.py` and select the input folder containing the log files to be processed.

This script will take a moment and generate many plots and tables.
