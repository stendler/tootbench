## History / Steps done created

Steps done to create this repo.

```sh
# add mastodon as git subtree
git subtree add --prefix mastodon https://github.com/mastodon/mastodon.git v4.0.2 --squash
```

Creating the `.env.production` file (especially the secrets and keys):

```sh
# build devcontainer to be able to run config setup scripts
docker build -t devcontainer/mastodon --build-arg=VARIANT=3.1-bullseye --build-arg=NODE_VERSION=14 .mastodon/devcontainer/
```

```sh
# run and setup devcontainer
docker run -it --rm --user 1000 -e RAILS_ENV=production -v "$(pwd)":/workspaces/mastodon --workdir=/workspaces/mastodon devcontainer/mastodon /bin/bash
## inside the container run (taken from devcontainer.json postCreateCommand - a bit bloated, but it works)
cd mastodon
rvm install ruby-3.0.4 && bundle install --path vendor/bundle && yarn install && gem install rake

## interactive mastodon config setup
# rake mastodon:setup # not really working with docker, just create the file by hand and add the secrets manually
rake secret
rake mastodon:webpush:generate_vapid_key
# rake assets:precompile # somehow ar

cd ..
```

Create a symlink to the new .env-file (ignored by the gitignore within the mastodon folder).

```sh
ln -s ../.env.production mastodon/.env.production
```

Run in docker compose:

```sh
cd mastodon
docker compose run --rm db-migrate # setup db on first run
docker compose run --rm precompile-assets
```

Problem: no ssl but production mode requires ssl

--> set up a reverse proxy (added to the docker-compose.yml) https://docs.joinmastodon.org/admin/install/#setting-up-nginx

Generate certificates using [minica]

```sh
# to build minica in docker:
docker build -t minica minica/.
# create a certificate for localhost
docker run --rm -v "$(pwd)/cert:/cert" -u $(id -u):$(id -g) minica --domains localhost
```

User setup: https://docs.joinmastodon.org/admin/setup/

> **Note:** There is an issue with DNS, since the tootctl container is only within the internal network.
> But it performs a DNS resolve against the provided E-mail domain, which will thus fail.
> Only its own hostname (and possibly other hostnames within the network) will resolve as valid E-mail domains.

Use these commands or the corresponding shell scripts `createAdminUser.sh` and `createUser.sh`.

```sh
# creating an admin user (with role Owner)
docker compose --project-directory mastodon run -it --rm --entrypoint "bash -c" tootctl 'tootctl accounts create toor --email root@$(hostname) --confirmed --role Owner'
# create any other user
docker compose --project-directory mastodon run -it --rm --entrypoint "bash -c" tootctl "tootctl accounts create user01 --email user01@\$(hostname) --confirmed"
```

### Cloud

If you don't want to or cannot install terraform and gcloud sdk locally, you can use it through docker:

```sh
docker build -t gcloud-terraform:412 gcloud-terraform
docker run -i --rm --entrypoint /bin/bash -v "$(pwd)/plans:/home/cloudsdk/plans" -v gcloud-config-personal:/home/cloudsdk/.config -v gcloud-config-root:/root/.config --name gcloud-terraform -w /home/cloudsdk/plans gcloud-terraform:412
```

Now you can run the following commands from within the container.

Setup gcloud

```sh
gcloud auth login
gcloud config set project cloud-service-benchmarking-22
gcloud config set compute/zone europe-west1-b
gcloud auth application-default login
gcloud auth application-default set-quota-project cloud-service-benchmarking-22
ssh-keygen -f .ssh/id_ed25519 -t ed25519
```

Setup terraform:

```sh
terraform -chdir=terraform init
terraform -chdir=terraform apply
# update ssh 
gcloud compute config-ssh --ssh-key-file=.ssh/id_ed25519
```

Reboot a single instance:

```sh
terraform -chdir=terraform -replace=google_compute_instance.instance -var-file="secrets.tfvars"
```

Copy files for testing:

```sh
rsync -azh --filter=':- .gitignore' --exclude=.git . ansible@mstdn-single-instance.europe-west1-b.cloud-service-benchmarking-22:project
ssh ansible@mstdn-single-instance.europe-west1-b.cloud-service-benchmarking-22
```

--> now all done with terraform and cloud-init. The client can reach mastodon on instance.
Problem: https cannot be verified due to self-signed certificate.

Destroy

```sh
terraform -chdir=terraform  destroy -var-file=secrets.tfvars
```

Moved these into scripts:

```sh
./scripts/setup-single-instance.sh # setup and deploy everything (including certs)
./scripts/restart-instance.sh # optionally with a terraform resource name to be restarted (default: "instance client")
./scripts/destroy-single-instance.sh # shutdown
```

#### (obsolete) Create and push reused images

```sh
gcloud artifacts repositories create tootsuite --repository-format=docker --location europe-west1
cd mastodon
gcloud builds submit --tag europe-west1-docker.pkg.dev/cloud-service-benchmarking-22/tootsuite/mastodon
```

AAAND disabled again. The image is available on the docker hub. --> Creating a docker-compose.yml
