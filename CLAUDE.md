# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A local-only Docker Compose stack that runs one PHP site at a time. `CMS` in `.env` picks the NGINX template, and the `cli` container (`digitalblake/light-cli`) installs and manages the site. README.md covers usage. The docs folder holds the reasons behind each setting:

- `docs/security.md` covers capabilities, networks, mounts, and the gateway.
- `docs/xdebug.md` covers debugging, profiling, and Webgrind.
- `docs/tuning.md` covers the PHP, OPcache, FPM, MariaDB, and Redis settings.
- `docs/other-apps.md` covers the tested install steps for non-CMS PHP apps.

## Rules specific to this repo

- No comments in code or config files. That covers `compose.yml`, Dockerfiles, ini, NGINX conf and templates, and zsh. Put the reason for a setting in the matching `docs/*.md` file instead. `grep -rn -E '^\s*(#|;|//)' compose.yml docker/` should return only the `;;` lines in `functions.zsh`.
- The env template is `env.example`, not `.env.example`. The permission settings block reading and writing `.env` and `.env.*`, so pass `--env-file env.example` to `docker compose` when testing.
- Host ports use the block 24210 to 24219, which is recorded in `../digitalblake-system-setup/notes/dev-ports.md`. Every published port binds to `127.0.0.1`.
- Pin every image to an exact tag, and pin PECL and download versions with a checksum where one exists.

## Running things from Claude Code

- The sandbox blocks the Docker socket and writes inside `.git`. Run `docker` and `git` commands with the sandbox disabled, and set `DOCKER_HOST=unix:///Users/bcerecero/.docker/run/docker.sock`.
- zsh does not word-split variables, so wrap compose in a function instead of a string variable:

    ```sh
    dc() { CMS=wordpress docker compose --env-file env.example "$@"; }
    ```

- Requests to `127.0.0.1:24210` and the other host ports also need the sandbox disabled.
- `scripts/hard-reset.sh` refuses to run without a TTY. Drive it with `expect`:

    ```sh
    expect -c 'set timeout 120; spawn ./scripts/hard-reset.sh; expect "to cancel: "; send "reset\r"; expect eof'
    ```

- A safety check blocks `rm -rf` inside `find -exec` or `sh -c`. Delete explicit paths, or use `hard-reset.sh`.

## Checks

There is no test suite. A change is verified by running the stack:

- `docker compose --env-file env.example config -q` validates the Compose file.
- Run `docker compose build php webgrind` after changing `docker/php` or `docker/webgrind`.
- To check an NGINX template, run `nginx -t` in the nginx container after the template is rendered. Set `CMS` and `DOCROOT` on the command line:

    ```sh
    CMS=drupal DOCROOT=/var/www/html/web docker compose --env-file env.example run --rm --no-deps nginx \
    	sh -c '/docker-entrypoint.d/20-envsubst-on-templates.sh >/dev/null && nginx -t'
    ```

- For an end-to-end check, run `up -d`, then install a site with `docker compose exec -T cli zsh -ic cms-install`, feeding the four prompts on stdin. Then `curl` the site and the blocked paths.
- Run `shellcheck scripts/hard-reset.sh`.
- Format Markdown and JSON with Prettier through light-cli, because Prettier is not installed on the host:

    ```sh
    docker run --rm -v "$PWD":/work -w /work digitalblake/light-cli:6.6.0 sh -c 'npx --yes prettier@3 --print-width 120 --no-semi --single-quote --tab-width 4 --trailing-comma es5 --use-tabs --write README.md CHANGELOG.md docs/*.md'
    ```

- Run a Snyk container scan on the built `generic-server-php` and `generic-server-webgrind` images. Snyk cannot reach Docker Desktop, so `docker save` each image to a tar file and scan `docker-archive:<path>`.

## Architecture

### Networks and the gateway

- `backend` is `internal: true` and has no internet access. Every service joins it.
- `egress` has internet access, and only `php` and `cli` join it. `cli` needs it for Composer and CMS downloads. `php` needs it because Xdebug connects to `host.docker.internal:9003`.
- On Docker Desktop, a port published by a container that is only on an internal network cannot be reached from the Mac. So `gateway`, an nginx container with a fixed config in `docker/gateway/nginx.conf`, is the only container on the `published` network. It forwards host ports 24210 to 24214 to the nginx, db (TCP stream), phpmyadmin, mailpit, and webgrind services. A new service with a web UI gets a new `server` block there and a port mapping on `gateway`, and it does not publish ports of its own.
- `cli` publishes its own browser-sync ports because it is already on `egress`.

### Hardening

The `x-hardening` anchor gives every service these settings:

- `read_only: true`
- `cap_drop: ALL`
- `no-new-privileges`
- `pids_limit`

Writable paths are tmpfs mounts. Services add back only the capabilities they fail without, and `docs/security.md` lists each one. `cli` keeps a writable root filesystem because light-cli's zsh, Corepack, Composer, and wp-cli write into `$HOME`. Moving those caches made Corepack download the wrong pnpm version.

### CMS selection

The nginx service mounts `docker/nginx/${CMS}.conf.template` with `create_host_path: false`, so a missing template fails at startup. The nginx image's envsubst step fills in `${DOCROOT}` and leaves NGINX's own `$uri`-style variables alone. All templates include two shared snippets:

- `snippets/common.conf` has the headers, gzip, dotfile blocking, and `/nginx-health`.
- `snippets/php-fpm.conf` has the FastCGI settings.

`wordpress`, `joomla`, `drupal`, `generic`, and `grav` exist today. Adding an app type means adding one template file. `cms-install` only has installers for the first three, and for any other `CMS` value it prints a pointer to `composer-create` and `docs/other-apps.md`.

### Paths and the cli container

- `./app` is mounted at `/var/www/html` in nginx (read-only), php, and cli. The path has to be the same in php and cli because Joomla writes absolute paths into `configuration.php`.
- `docker/cli/functions.zsh` is bind-mounted as a single file over light-cli's own `functions.zsh`. Editing it on the host with `sed -i` or an editor that replaces the file leaves the container on the old inode. Recreate `cli` after every edit with `docker compose up -d --force-recreate cli`.
- `docker/cli/php.ini` raises light-cli's CLI `memory_limit`. The 128M default fails on `wp core download`.
- `_composer_create` in `functions.zsh` installs into `$SERVER_DIR/.cms-staging` and then runs rsync into `./app`, because `./app` always holds `.gitkeep`.
- The cli container has `DB_NAME`, `DB_USER`, and `DB_PASSWORD` set as environment variables. The php container does not, and PHP-FPM keeps its default `clear_env`. So each app stores its database values in its own config file.

### Images built here

- `docker/php/Dockerfile` builds on `php:8.4.x-fpm-alpine`, runs as `www-data`, and installs Xdebug, redis, and imagick from PECL with pinned versions. PHP's `mail()` goes through `msmtp` to `mailpit:1025`.
- `docker/webgrind/Dockerfile` builds Webgrind from a SHA-256-pinned GitHub archive. The upstream image has no arm64 build and runs PHP 7.4.
- `xdebug.use_compression = 0` is required, because Webgrind's `gprof2dot.py` cannot read gzipped profiles.

### light-cli

`digitalblake/light-cli` comes from `../light-cli`, a separate repository. The PHP extensions that the CLI tools need, such as pdo_mysql for Drush or bcmath for Craft, are added to `../light-cli/Dockerfile`. The image is then rebuilt locally with a version bump, and the tag in `compose.yml` is updated to match. Each bump so far has had to stay under 75 MB of growth, and a bigger addition goes in a thin local Dockerfile instead.

## Docs and changelog

- Load the `plain-statements` skill before editing README.md, CHANGELOG.md, or `docs/`.
- The `statements-lint` hook runs on every Markdown edit.
- CHANGELOG.md follows Keep a Changelog, with one version per feature.
- `docs/other-apps.md` only lists apps that were installed and loaded in the stack, with the version tested.
