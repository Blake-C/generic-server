# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
