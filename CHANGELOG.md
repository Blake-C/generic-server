# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.4.0] - 2026-10-07

### Added

- `phpcs.xml.dist` at the repository root, which excludes every file so code without its own ruleset is not checked and the PHP_CodeSniffer extension stops reporting a missing configuration file.
- `.vscode/settings.json`, which sets the PHP_CodeSniffer extension to find each app's ruleset and each app's own `vendor/bin/phpcs`.
- `docs/coding-standards.md` with tested example rulesets for WordPress, Drupal, Joomla, and the PHP frameworks.

## [1.3.1] - 2026-10-07

### Fixed

- phpMyAdmin showed "Failed to read configuration file!" because its startup script could not write `config.secret.inc.php` on the read-only root filesystem. The secret now comes from `PMA_BLOWFISH_SECRET` in `.env` through a read-only `docker/phpmyadmin/config.secret.inc.php`.

## [1.3.0] - 2026-10-07

### Changed

- The php image builds GD with AVIF support, which clears Drupal's "Unsupported image file format: AVIF" status report warning.
- `cms-install` sets `$settings['enable_html5_validation'] = FALSE;` in Drupal's `settings.php`, which clears Drupal 11.4's HTML5 validation status report warning.

## [1.2.0] - 2026-10-07

### Added

- `CMS=generic` and `docker/nginx/generic.conf.template` for PHP apps other than WordPress, Joomla, and Drupal.
- `docker/nginx/grav.conf.template`, based on the NGINX config that ships with Grav.
- `composer-create`, which runs `composer create-project` into `./app` even though `./app` holds a `.gitkeep`.
- `docs/other-apps.md` with tested steps for Laravel, Symfony, CodeIgniter 4, CakePHP, Craft CMS, Statamic, and Grav.

### Changed

- The cli container uses light-cli 6.6.0, which adds the bcmath, exif, pcntl, pdo_sqlite, sqlite3, redis, and imagick PHP extensions.
- `CMS` can name any template in `docker/nginx`. If the template file does not exist, `docker compose up` stops with an error.
- `cms-install` prints the `composer-create` command and the path to `docs/other-apps.md` when `CMS` is not `wordpress`, `joomla`, or `drupal`.

## [1.1.0] - 2026-10-07

### Added

- `scripts/hard-reset.sh`, which stops the stack and deletes the site code, database, and Xdebug files after you type `reset` to confirm.

## [1.0.0] - 2026-10-07

### Added

- Docker Compose stack that runs one WordPress, Joomla, or Drupal site, picked with `CMS` in `.env`.
- PHP-FPM 8.4.26 image with Xdebug 3.5.3, phpredis 6.3.0, Imagick 3.8.1, and msmtp.
- NGINX templates for WordPress, Joomla, and Drupal.
- MariaDB 12.3.3, Redis 8.10.2, phpMyAdmin 5.2.3, and Mailpit 1.31.4.
- Webgrind 1.9.4 image built from source on PHP 8.4.
- light-cli 6.5.0 cli container with `cms-install`, `db-export`, `db-import`, `db-cli`, and `drush` and `joomla` aliases.
- Container hardening with dropped capabilities, read-only root filesystems, an internal-only backend network, and a gateway container that forwards the host ports.
- VS Code launch configuration for Xdebug.
