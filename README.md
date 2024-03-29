![tootbench logo](logo-text.png)

(Image Attribution: adapted from [Midjourney](https://www.midjourney.com) [CC-BY-NC](https://creativecommons.org/licenses/by-nc/4.0/legalcode))

## About

This repository is the result of the portfolio examination of the
[Cloud Service Benchmarking course](https://moseskonto.tu-berlin.de/moses/modultransfersystem/bolognamodule/beschreibung/anzeigen.html?nummer=41035&version=2&sprache=2)
by @dbermbach, @martingrambow and @njapke at TU Berlin.

This project benchmarks the overhead of [Mastodons](https://github.com/mastodon/mastodon) federation in different
[scenarios](terraform/scenarios) in the Google Cloud Platform.  

![Architecture Overview](architecture-overview.png)

Results for Mastodon v4.0.2 can be found in the jupyter notebook in [`analysis/plot.ipynb`](analysis/plot.ipynb)
or [here in the report (including the raw files)](https://tubcloud.tu-berlin.de/s/ypKF9b7oN3dHNNd).  
The source code resides at [GitHub](https://github.com/stendler/tootbench) and [TU GitLab](https://git.tu-berlin.de/stendler/tootbench).

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

Which is short for:

```sh
max_instances=10  # just to be sure; 3 are enough for the current biggest scenario

# if running inside docker: to be able to mount a volume from the host
if [ -z "$HOST_VOLUME_MOUNT" ]; then
  HOST_VOLUME_MOUNT="$(pwd)"
  echo "No HOST_VOLUME_MOUNT set. Assuming running on the host and the following directory is accessible by the docker daemon: $HOST_VOLUME_MOUNT"
fi

# generate an ssh key to access the gcloud machines
ssh-keygen -f .ssh/id_ed25519 -t ed25519
# build the minica image and run it once, to create the root certificate
docker build -t minica minica/. # if not done already
docker run --rm -v "$HOST_VOLUME_MOUNT/cert:/cert" minica --domains localhost
# transform the root cert into a format Java understands and create a build of the client with that cert
openssl x509 -outform der -in cert/minica.pem -out client/src/main/resources/minica.der
./scripts/build.sh
# generate multiple secrets to be used by mastodon instances
echo "secrets:" > terraform/secrets.yaml
# repeat as much as maximum parallel instances to be deployed
for i in $(seq $max_instances); do
  echo "Generating instance secrets [$i/$max_instances]"
  ./scripts/secrets.sh >> terraform/secrets.yaml
done
# initialize terraform and install used modules
terraform -chdir=terraform init
```

#### Manual deployment

(see `make help` for available scenarios and if requirements are fulfilled)

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


## Repository structure

- `.run`: contains an IntelliJ run configuration to create the gcloud-terraform Docker image and open a terminal inside a new container of that
- `analysis` python project for analysis scripts
  - `/input` preprocessed input files
  - `/output` generated result files e.g., plots, tables in different formats
  - `/preprocessing` utility scripts used by `preprocess.sh` to preprocess files in `playbooks/logs/`
  - `/picasso.py` cli entrypoint for analysis
- `client` Java project for the tootbench load client application
- `gcloud-terraform/Dockerfile` Image with (almost) all necessary dependencies
- `mastodon` git subtree of the original mastodon v3.5.5 source for custom builds with some applied patches for additional logs and (almost) practically disabled rate-limiting
  - for a prebuilt docker image see https://git.tu-berlin.de/stendler/tootbench/container_registry/978
- `minica/Dockerfile` Image to easily create TLS certificates into `cert`
- `playbooks` Ansible playbooks for the benchmark deployment lifecycle: await-init, prepare, start, wait, stop, collect, clean
  - `/logs` output folder for collected logs by timestamp (plus additional comment configured in `./tootbench` cli argument)
- `scripts` mainly scripts used in the Makefile for the benchmark deployment lifecycle
  - `/util` administration utility scripts used on the deployed mastodon instances 
- `terraform` Terraform and cloud-init declaration of the used infrastructure 
  - `/scenarios` Contains a `.tfvars` file for each scenario to be benchmarked
- `Makefile` simple way to use the utility scripts and manually instruct deployments. See `make help`
- `tootbench` CLI script to orchestrate a benchmark of multiple scenarios and multiple runs. See `./tootbench --help`
