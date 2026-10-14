# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.7.1] - 2026-10-14

### Changed

- The cli container uses light-cli 6.8.0, which updates Alpine to 3.24.2, npm to 11.21.0, and pnpm to 12.10.1.

## [1.7.0] - 2026-10-13

### Added

- A `playwright` service that runs the Playwright MCP server 0.0.83 with headless Chromium, so an AI agent can open the site and its admin and save screenshots to `./data/screenshots`. The MCP server is at http://localhost:24217/mcp, and `.mcp.json` connects Claude Code to it.
- `PLAYWRIGHT_INTERNET` in `.env`, which is `off` by default. With `off`, the playwright browser sends every request except the ones to `localhost` to a proxy port that nothing listens on, so it can only load pages from the stack. With `on`, the browser can load pages from the internet.
- `docs/playwright.md`, which covers the URLs the browser opens, where screenshots are saved, logging in, drawing arrows on a page before a screenshot, and updating the image. It also lists what WordPress screenshots are missing with `PLAYWRIGHT_INTERNET=off` and the risks of turning it on.
- `CLAUDE.md` and `AGENTS.md` tell agents to explain those risks and wait for confirmation before turning internet access on.

### Changed

- The gateway also listens on ports 24210, 24212, 24213, and 24214 inside its container, so the playwright browser opens the same URLs as the Mac.

## [1.5.1] - 2026-10-08

### Added

- `cms-install` asks whether to install Drupal core or Drupal CMS 2 when `CMS=drupal`, and for Drupal CMS it then asks for the Starter or Blank site template.
- The php image has the pdo_pgsql extension, which the amazee.io AI provider in Drupal CMS 2 requires.

### Changed

- The cli container uses light-cli 6.7.0, which adds pdo_pgsql so Composer can install Drupal CMS 2.

### Security

- The Drupal NGINX template returns 403 for every PHP file under `sites`, so a request for `/sites/default/settings.php` no longer runs the file. On Drupal CMS, running `settings.php` printed PHP warnings that showed the file's full path.

## [1.4.0] - 2026-10-07

### Added

- Docker Compose stack that runs one PHP site, picked with `CMS` in `.env`. `CMS` can name any template in `docker/nginx`, and if the template file does not exist, `docker compose up` stops with an error.
- NGINX templates for WordPress, Joomla, Drupal, Grav, and a `generic` template for other PHP apps. The Grav template is based on the NGINX config that ships with Grav.
- PHP-FPM 8.4.26 image with Xdebug 3.5.3, phpredis 6.3.0, Imagick 3.8.1, msmtp, and GD built with AVIF support, which clears Drupal's "Unsupported image file format: AVIF" status report warning.
- MariaDB 12.3.3, Redis 8.10.2, phpMyAdmin 5.2.3, and Mailpit 1.31.4.
- phpMyAdmin reads its secret from `PMA_BLOWFISH_SECRET` in `.env` through a read-only `docker/phpmyadmin/config.secret.inc.php`, because its startup script cannot write `config.secret.inc.php` on the read-only root filesystem.
- Webgrind 1.9.4 image built from source on PHP 8.4.
- light-cli 6.6.0 cli container with `cms-install`, `db-export`, `db-import`, `db-cli`, and `drush` and `joomla` aliases. light-cli 6.6.0 has the bcmath, exif, pcntl, pdo_sqlite, sqlite3, redis, and imagick PHP extensions.
- `cms-install` installs WordPress, Joomla, or Drupal. For Drupal it sets `$settings['enable_html5_validation'] = FALSE;` in `settings.php`, which clears Drupal 11.4's HTML5 validation status report warning. For any other `CMS` value it prints the `composer-create` command and the path to `docs/other-apps.md`.
- `composer-create`, which runs `composer create-project` into `./app` even though `./app` holds a `.gitkeep`.
- `docs/other-apps.md` with tested steps for Laravel, Symfony, CodeIgniter 4, CakePHP, Craft CMS, Statamic, and Grav.
- `scripts/hard-reset.sh`, which stops the stack and deletes the site code, database, and Xdebug files after you type `reset` to confirm.
- `phpcs.xml.dist` at the repository root, which excludes every file so code without its own ruleset is not checked and the PHP_CodeSniffer extension stops reporting a missing configuration file.
- `.vscode/settings.json`, which sets the PHP_CodeSniffer extension to find each app's ruleset and each app's own `vendor/bin/phpcs`.
- `docs/coding-standards.md` with tested example rulesets for WordPress, Drupal, Joomla, and the PHP frameworks.
- Container hardening with dropped capabilities, read-only root filesystems, an internal-only backend network, and a gateway container that forwards the host ports.
- VS Code launch configuration for Xdebug.
