# PHP, PHP-FPM, and MariaDB settings

These settings are tuned for one developer working on one site on a laptop. Most of them come from the `core-wp` project.

## PHP (`docker/php/php.ini`)

| Setting                                | Value                  | Reason                                                                                               |
| -------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------- |
| `memory_limit`                         | 512M                   | Drupal installs and large admin screens in all three CMSs need more than the 128M default            |
| `upload_max_filesize`, `post_max_size` | 64M                    | Matches `client_max_body_size` in NGINX so large media uploads are not cut off                       |
| `max_execution_time`                   | 300                    | Gives slow installer and update requests time to finish, and matches `fastcgi_read_timeout` in NGINX |
| `max_input_vars`                       | 5000                   | Large menus and permission forms in Joomla and Drupal post more than the 1000 default                |
| `display_errors`                       | On                     | Shows errors in the browser while developing                                                         |
| `error_log`                            | `/proc/self/fd/2`      | Sends PHP errors to `docker compose logs php`                                                        |
| `sendmail_path`                        | `/usr/bin/msmtp -t -i` | Sends mail to Mailpit using `docker/php/msmtprc`                                                     |

The cli container has its own `docker/cli/php.ini`, which raises `memory_limit` to 1G. light-cli's PHP default of 128M ran out of memory while `wp core download` unpacked WordPress.

## OPcache (`docker/php/opcache.ini`)

- `validate_timestamps = 1` with `revalidate_freq = 0` makes OPcache check every file's modified time on each request. Edits show up on the next page load, and unchanged files still run from the cache.
- `enable_cli = 0` turns OPcache off for CLI commands run in the php container, where each command is a new process and the cache would be thrown away when it exits.
- `jit_buffer_size = 0` turns off the JIT, which is the same setting core-wp uses in development.
- `save_comments = 1` keeps doc comments, which Drupal and Doctrine read as annotations.

## PHP-FPM (`docker/php/www.conf`)

- `pm = dynamic` starts 4 workers and grows to 20 when more requests come in at once, then trims idle workers back to between 2 and 8.
- `pm.max_requests = 500` restarts each worker after 500 requests, which clears any memory a plugin or module leaks.
- `request_slowlog_timeout = 5s` writes a stack trace to `docker compose logs php` for any request that takes longer than 5 seconds.
- The php container runs PHP-FPM as www-data, so the `user` and `group` settings are left out.

## MariaDB (`docker/mariadb/my.cnf`)

- `innodb_buffer_pool_size = 256M` is enough to keep a local site's tables and indexes in memory without taking much of the laptop's RAM.
- `innodb_flush_log_at_trx_commit = 2` flushes the transaction log once per second instead of on every commit. Writes are faster, and an operating system crash or power loss can lose up to one second of committed data, which is fine for a local site.
- `slow_query_log` with `long_query_time = 0.5` logs every query that takes longer than half a second to `./data/mariadb/slow.log`.
- `max_allowed_packet = 64M` lets `db-import` load dumps with large rows, such as serialized options and cache tables.
- `character_set_server = utf8mb4` sets the server's default character set to the one all three CMSs use, and `collation_server = utf8mb4_unicode_ci` sets its default collation. Each CMS can still pick its own collation when it creates tables.

## Redis

Redis runs as a cache only, so `--save ''` and `--appendonly no` turn off writing to disk, and `--maxmemory 128mb` with `allkeys-lru` drops the least recently used keys when it is full.

WordPress gets `WP_REDIS_HOST` set to `redis` in `wp-config.php`, which the Redis Object Cache plugin reads. Joomla and Drupal need their Redis settings added by hand, using `redis` as the host and `6379` as the port.
