

### Steps done created

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
## inside the container run (taken from devcontainer.json postCreateCommand)
cd mastodon
rvm install ruby-3.0.4 && bundle install --path vendor/bundle && yarn install && gem install rake

## interactive mastodon config setup
# rake mastodon:setup # not really working with docker
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
docker compose run db-migrate # setup db on first run
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
- first run commands (`docker compose run migrate precompile-assets`)
- nginx envsubst native
- use volume for certs

# terraform: client vm & server vm

# ansible? compose
