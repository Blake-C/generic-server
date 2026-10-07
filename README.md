# generic-server

A local Docker stack that runs one WordPress, Joomla, or Drupal site at a time. It is for local development only and should never be used in production.

The `CMS` value in `.env` picks which NGINX config is loaded, and the `cli` container installs and manages the site with `digitalblake/light-cli`.

## Services

All host ports bind to `127.0.0.1`, so nothing is reachable from other machines on the network. This project uses the 24210 to 24219 port block from `digitalblake-system-setup/notes/dev-ports.md`.

| Service    | What it runs                                                                                           | Host address                     |
| ---------- | ------------------------------------------------------------------------------------------------------ | -------------------------------- |
| gateway    | NGINX proxy that forwards every host port below except the cli ports                                   |                                  |
| nginx      | NGINX web server for the site                                                                          | http://localhost:24210           |
| php        | PHP-FPM 8.4 with Xdebug, Redis, and Imagick                                                            |                                  |
| db         | MariaDB 12.3                                                                                           | 127.0.0.1:24211                  |
| phpmyadmin | phpMyAdmin 5.2                                                                                         | http://localhost:24212           |
| mailpit    | Mailpit, which catches every email PHP sends                                                           | http://localhost:24213           |
| webgrind   | Webgrind, which reads Xdebug profiles                                                                  | http://localhost:24214           |
| redis      | Redis 8 object cache                                                                                   |                                  |
| cli        | light-cli 6.5.0 with wp-cli, Composer, pnpm, and browser-sync. Drupal sites get Drush through Composer | 24215 and 24216 for browser-sync |

Only the gateway, php, and cli containers can reach the internet. [docs/security.md](docs/security.md) explains why and lists what each container is allowed to do.

## Requirements

- Docker Desktop
- The `digitalblake/light-cli:6.5.0` image. Version 6.5.0 adds the PHP extensions that Drush and the Joomla installer need. Build it from the `light-cli` repository with `docker build -t digitalblake/light-cli:6.5.0 .` until it is published to Docker Hub.

## Setup

1. Copy the environment template, then change both database passwords in `.env`.

    ```sh
    cp env.example .env
    ```

2. Set `CMS` and `DOCROOT` in `.env` for the site you want.

    | CMS       | `CMS`       | `DOCROOT`           |
    | --------- | ----------- | ------------------- |
    | WordPress | `wordpress` | `/var/www/html`     |
    | Joomla    | `joomla`    | `/var/www/html`     |
    | Drupal    | `drupal`    | `/var/www/html/web` |

3. Start the stack.

    ```sh
    docker compose up -d
    ```

4. Open a shell in the cli container and install the site. `cms-install` asks for a site name and an admin username, email, and password.

    ```sh
    docker compose exec cli zsh
    cms-install
    ```

The site is then at http://localhost:24210. The code is in `./app` on your machine and at `/var/www/html` inside the nginx, php, and cli containers.

## What `cms-install` does

- **WordPress**: downloads the latest WordPress with `wp core download`, writes `wp-config.php` from the database values in `.env`, runs `wp core install`, and sets post-name permalinks.
- **Joomla**: downloads the Joomla release named by `JOOMLA_VERSION` (6.1.4 by default) from GitHub, checks its SHA-256 digest against the one GitHub lists for that release, and runs the Joomla CLI installer. The installer deletes the `installation` folder when it finishes.
- **Drupal**: runs `composer create-project drupal/recommended-project`, adds Drush, runs `drush site:install standard`, and adds `localhost` and `127.0.0.1` to `trusted_host_patterns` in `settings.php`.

Each install uses a random four-letter table prefix. The admin password is never written to a file.

## CLI commands

These commands work inside the cli container.

| Command            | What it does                                                   |
| ------------------ | -------------------------------------------------------------- |
| `cms-install`      | Installs the CMS named by `CMS` into an empty `./app`          |
| `wp`               | wp-cli                                                         |
| `drush`            | Runs `vendor/bin/drush` from the Drupal project                |
| `joomla`           | Runs `php cli/joomla.php` from the Joomla site                 |
| `composer`         | Composer 2                                                     |
| `db-export`        | Writes a gzipped dump of the site database to `./data/backups` |
| `db-import <file>` | Loads a `.sql` or `.sql.gz` file into the site database        |
| `db-cli`           | Opens a MariaDB prompt on the site database                    |
| `root`             | Changes to `/var/www/html`                                     |

`docker/cli/functions.zsh` defines the commands that are not part of light-cli. Docker mounts that single file into the container, so after you edit it, recreate the cli container with `docker compose up -d --force-recreate cli` to load the new version.

## Resetting the project

`scripts/hard-reset.sh` puts the project back to the state it was in before `cms-install` ran. Run it in your Mac's terminal. It does not work inside the cli container, because that container cannot see `./data/mariadb` and cannot stop the other containers.

```sh
./scripts/hard-reset.sh
```

The script lists what it will delete and how much space each folder uses, then waits for you to type `reset`. Any other answer cancels without changing anything. It also refuses to run without an interactive terminal, so it cannot be confirmed by piping input into it.

After you confirm, it runs `docker compose down` and permanently deletes everything except `.gitkeep` from these folders:

- `./app`, which holds the site code, uploads, and config files such as `wp-config.php`
- `./data/mariadb`, which holds the whole database
- `./data/xdebug`, which holds Xdebug profiles and the Xdebug log

Nothing goes to the Trash. It keeps `.env`, `./data/backups`, and `./data/pnpm-store`. If `docker compose down` fails, for example because Docker Desktop is not running, the script stops before deleting anything.

Run `db-export` in the cli container first if you want to keep a copy of the database.

## Switching to a different CMS

The stack holds one site at a time, so switching deletes the current site and its database.

1. Run `./scripts/hard-reset.sh`.
2. Change `CMS` and `DOCROOT` in `.env`.
3. Start the stack and run `cms-install` again.

## Mail

The php container sends all mail from PHP's `mail()` function to Mailpit through `msmtp`, so password resets and notifications show up at http://localhost:24213 and never leave your machine. Mailpit stores messages on a tmpfs, so they are gone after the container restarts.

The cli container has no mail program, so email sent from a wp-cli or Drush command is not delivered anywhere.

## Debugging and profiling

Xdebug is installed in the php container and off by default. Set `XDEBUG_MODE` in `.env` to `debug`, `profile`, or `debug,profile`, then run `docker compose up -d php`. Xdebug only debugs or profiles requests that carry a trigger, such as `?XDEBUG_TRIGGER=1`.

[docs/xdebug.md](docs/xdebug.md) covers the VS Code setup, triggers, and reading profiles in Webgrind.

## Docs

- [docs/xdebug.md](docs/xdebug.md): step debugging and profiling
- [docs/security.md](docs/security.md): what each container can access and why
- [docs/tuning.md](docs/tuning.md): the reasons behind the PHP, OPcache, PHP-FPM, and MariaDB settings
