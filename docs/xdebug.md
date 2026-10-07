# Xdebug

The php container runs Xdebug 3.5.3. Its settings are in `docker/php/xdebug.ini`.

## Turning it on

`XDEBUG_MODE` in `.env` sets the Xdebug mode, and the default is `off`. Xdebug adds overhead to every PHP request while any mode is on, including requests without a trigger, so set the mode back to `off` when you are done.

| `XDEBUG_MODE`   | What it does                                           |
| --------------- | ------------------------------------------------------ |
| `off`           | Xdebug is loaded and does nothing                      |
| `debug`         | Step debugging in your editor                          |
| `profile`       | Writes a cachegrind profile for each triggered request |
| `debug,profile` | Both                                                   |

After changing it, run `docker compose up -d php` so the php container starts with the new value.

## Triggers

`xdebug.start_with_request` is set to `trigger`. With that setting, Xdebug only runs on a request that carries a trigger named `XDEBUG_TRIGGER` in the query string, a POST field, a cookie, or an environment variable ([Xdebug settings](https://xdebug.org/docs/all_settings#start_with_request)). Requests without the trigger are not debugged or profiled.

To trigger a single page, add `?XDEBUG_TRIGGER=1` to the URL:

```
http://localhost:24210/?XDEBUG_TRIGGER=1
```

Xdebug also accepts the older trigger names `XDEBUG_SESSION` for debugging and `XDEBUG_PROFILE` for profiling. A browser extension such as Xdebug Helper sets those as cookies, so the browser sends the trigger with admin pages and form posts without you editing any URLs.

## Step debugging in VS Code

1. Install the PHP Debug extension (`xdebug.php-debug`).
2. Open this repository folder in VS Code. `.vscode/launch.json` has a configuration named "Listen for Xdebug (generic-server)" that listens on port 9003 and maps `/var/www/html` in the container to `./app`.
3. Set `XDEBUG_MODE=debug` in `.env` and run `docker compose up -d php`.
4. Start the debug configuration, set a breakpoint in a file under `./app`, and load the page with the trigger.

Xdebug connects from the php container to `host.docker.internal:9003`, which Docker Desktop points at your Mac. The php container is on the `egress` network because a container on an internal-only network has no route to the host.

### Debugging a CLI command

light-cli does not include Xdebug. To step through a CLI script, run it in the php container instead, which has Xdebug and the same code at the same path:

```sh
docker compose exec -e XDEBUG_TRIGGER=1 php php path/to/script.php
```

## Profiling with Webgrind

1. Set `XDEBUG_MODE=profile` in `.env` and run `docker compose up -d php`.
2. Load the page you want to measure with `?XDEBUG_TRIGGER=1`.
3. Open http://localhost:24214 and pick the profile from the list.

Profiles are written to `./data/xdebug` and named `cachegrind.out.<timestamp>.<request URI>`. Webgrind reads that folder read-only, so delete old profiles from `./data/xdebug` on your machine. The same files open in PhpStorm and in QCachegrind.

`xdebug.use_compression` is set to `0`. Xdebug gzips profile files by default when it has gzip support ([Xdebug settings](https://xdebug.org/docs/all_settings#use_compression)), and the `gprof2dot.py` script that Webgrind 1.9.4 uses to draw the call graph failed with a `UnicodeDecodeError` on the gzipped files in testing.

Xdebug's own log is written to `./data/xdebug/xdebug.log`. Check it first if the editor never receives a connection.

## Why Webgrind is built here

The `jokkedk/webgrind:1.9.4` image on Docker Hub has no arm64 build, and it runs on PHP 7.4. `docker/webgrind/Dockerfile` downloads the Webgrind 1.9.4 source from GitHub, checks it against a pinned SHA-256 digest, compiles Webgrind's C++ preprocessor, and serves it with PHP 8.4's built-in web server.

The build changes these Webgrind settings in `config.php`:

- `profilerDir` is `/profiles`, where `./data/xdebug` is mounted.
- `storageDir` is `/tmp`, so Webgrind's cache files go to a tmpfs instead of the profiles folder.
- The file viewer is limited to files under `/host`, where `./app` is mounted read-only at `/host/var/www/html`, which matches the paths recorded in each profile.
- The version check is off, because the webgrind container has no internet access.
