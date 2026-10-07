# Container access

The access settings for every container are in `compose.yml`.

## Settings every container shares

The `x-hardening` block at the top of `compose.yml` applies these settings to every service:

- `cap_drop: ALL` removes every Linux capability. A service gets a capability back only when it fails to start without it, and the table below lists each one.
- `no-new-privileges` stops a process from gaining privileges through setuid programs. In the cli container this means `sudo` no longer works, and nothing in this stack needs it.
- `read_only: true` makes the container's root filesystem read-only. The paths a service has to write to are mounted as tmpfs, which is memory that is cleared when the container stops.
- `pids_limit: 256` caps how many processes a container can run. cli raises it to 512.
- `restart: unless-stopped` restarts a service if it exits. cli is set to `restart: 'no'`.

Each service also sets its own `mem_limit` and `cpus` to cap its memory and CPU use.

Every image tag is pinned to an exact version.

## Per service

| Service    | Runs as                       | Capabilities added                              | Read-only root | Writable paths                                               |
| ---------- | ----------------------------- | ----------------------------------------------- | -------------- | ------------------------------------------------------------ |
| gateway    | nginx                         | none                                            | yes            | `/tmp`                                                       |
| nginx      | root master, nginx workers    | `CHOWN`, `SETUID`, `SETGID`, `NET_BIND_SERVICE` | yes            | `/tmp`, `/var/run`, `/var/cache/nginx`, `/etc/nginx/conf.d`  |
| php        | www-data                      | none                                            | yes            | `/tmp`, `./app`, `./data/xdebug`                             |
| cli        | webdev                        | none                                            | no             | everything except mounted config                             |
| db         | mysql                         | none                                            | yes            | `/tmp`, `/run/mysqld`, `./data/mariadb`                      |
| redis      | redis                         | none                                            | yes            | `/data`                                                      |
| phpmyadmin | root master, www-data workers | `SETUID`, `SETGID`, `NET_BIND_SERVICE`          | yes            | `/tmp`, `/var/run/apache2`, `/var/lock/apache2`, `/sessions` |
| mailpit    | nobody                        | none                                            | yes            | `/tmp`                                                       |
| webgrind   | www-data                      | none                                            | yes            | `/tmp`                                                       |

- The nginx master process starts as root so it can listen on port 80, change the owner of its temp folders with `CHOWN`, and start workers as the nginx user with `SETUID` and `SETGID`. It failed to start in testing with `CHOWN` removed.
- phpMyAdmin's Apache starts as root for the same reasons, minus `CHOWN`.
- The `/etc/nginx/conf.d` tmpfs is where the nginx image writes `default.conf` after it fills in `${DOCROOT}` in the template for the chosen CMS.

### Why cli has a writable root filesystem

light-cli's zsh setup writes `~/.zcompdump` when it starts, and Corepack, Composer, and wp-cli keep caches in the webdev home folder. A tmpfs mount covers a folder, which cannot replace a single file like `~/.zcompdump`. When the caches were pointed somewhere else, Corepack could no longer find the pnpm 12.3.4 that light-cli pins and downloaded a different version. The cli container keeps a writable root filesystem, and anything it writes outside the mounted folders is deleted when the container is recreated.

## Mounts

- Config files are mounted read-only.
- nginx mounts `./app` read-only.
- php and cli mount `./app` read-write, because php writes uploads and cache files and cli runs installs and Composer.
- webgrind mounts `./data/xdebug` and `./app` read-only.
- No container mounts the Docker socket, your home folder, or anything outside this repository.

## Networks

| Network     | Internet access         | Members       |
| ----------- | ----------------------- | ------------- |
| `backend`   | none (`internal: true`) | every service |
| `egress`    | yes                     | php, cli      |
| `published` | yes                     | gateway       |

- A container that is only on `backend` cannot open any connection outside the stack. db, redis, nginx, phpMyAdmin, Mailpit, and Webgrind are on `backend` only.
- cli is on `egress` because Composer, wp-cli, and the CMS installers download packages.
- php is on `egress` because Xdebug connects to `host.docker.internal:9003`, which an internal-only network has no route to. As a result, CMS admin screens can still download plugins and updates. Use the cli container for Drupal installs anyway, so `composer.json` and `composer.lock` stay in sync with the files on disk.

### Why a gateway forwards the ports

In testing on Docker Desktop, a port published by a container that was only on an internal network could not be reached from the Mac. Turning off IP masquerading on a separate network did not block outbound connections either: a container on that network still loaded `http://example.com`.

So the gateway container is the only one on the `published` network, and it forwards each host port to the service behind it:

| Host port | Gateway port | Forwards to          |
| --------- | ------------ | -------------------- |
| 24210     | 8080         | nginx:80             |
| 24211     | 3306         | db:3306 (TCP stream) |
| 24212     | 8082         | phpmyadmin:80        |
| 24213     | 8083         | mailpit:8025         |
| 24214     | 8084         | webgrind:8080        |

The gateway runs NGINX as the nginx user with no capabilities, listens only on ports above 1024, and uses a fixed config from `docker/gateway/nginx.conf`. It has no access to the site code or the database files. cli publishes its browser-sync ports 24215 and 24216 itself, because it is already on `egress`.

## Credentials

- `.env` holds the database passwords and is listed in `.gitignore`.
- The database user that the CMS and the CLI connect as has access to the site database only. The MariaDB root password is used by the db container and nothing else.
- PHP-FPM keeps its default `clear_env` setting, so the container's environment variables are not passed to PHP requests.
- `cms-install` reads the admin password with a hidden prompt. wp-cli receives it, and the database password, on standard input. `cms-install` passes both passwords to the Joomla and Drupal installers as command-line options, so they are visible in the cli container's process list while the installer runs.

## Downloads that are verified

- `wp core download` checks the MD5 hash that WordPress.org publishes for the release. If wp-cli cannot fetch the hash, it prints a warning and keeps going.
- `cms-install` checks the Joomla package against the SHA-256 digest that GitHub lists for that release asset, and deletes the download if they do not match.
- The Webgrind image build checks the source archive against a SHA-256 digest pinned in `docker/webgrind/Dockerfile`.

## Request blocking in the NGINX templates

Each template in `docker/nginx` blocks:

- dotfiles, except `/.well-known/`
- backup, log, SQL, and shell files

Each CMS also has its own blocked paths:

- **WordPress**: `wp-config.php`, `xmlrpc.php`, and PHP files under `wp-content/uploads`.
- **Joomla**: `configuration.php`, the `logs`, `tmp`, `cache`, `cli`, `libraries`, and `installation` folders, PHP files under `images`, and the query string patterns from Joomla's `htaccess.txt`. Because `installation` is blocked, Joomla's web installer does not work, and `cms-install` uses the CLI installer.
- **Drupal**: the rules from the [NGINX Drupal recipe](https://github.com/nginxinc/nginx-wiki/blob/master/source/start/topics/recipes/drupal.rst), which block `sites/*/private`, PHP under `sites/*/files`, PHP under `vendor`, and Drupal's YAML, Twig, and module source files.
