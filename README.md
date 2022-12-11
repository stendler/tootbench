## Usage

### Setup

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
docker run --rm -v "$(pwd)/cert:/cert" minica --domains localhost
```

## TODO
- maybe copy the docker-compose.yml into the project root (for modification differing from upstream) (e.g. differing env-files for federated instances)
- add admin user
- add users programmatically

# terraform: client vm & server vm

# ansible? compose
