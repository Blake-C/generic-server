# Other PHP apps

`CMS=generic` runs any PHP app that sends every request that is not a real file to `index.php`, which is how most PHP frameworks route requests. `cms-install` has no installer for these apps, so you install them yourself in the cli container.

Each app below was installed and loaded in this stack on 2026-10-07 at the version listed.

| App           | Package                   | Version tested                                         | `CMS`     | `DOCROOT`               |
| ------------- | ------------------------- | ------------------------------------------------------ | --------- | ----------------------- |
| Laravel       | `laravel/laravel`         | laravel/laravel 13.11.0 with laravel/framework 13.35.0 | `generic` | `/var/www/html/public`  |
| Symfony       | `symfony/skeleton`        | Symfony 8.1.8                                          | `generic` | `/var/www/html/public`  |
| CodeIgniter 4 | `codeigniter4/appstarter` | CodeIgniter 4.7.4                                      | `generic` | `/var/www/html/public`  |
| CakePHP       | `cakephp/app`             | CakePHP 5.4.3                                          | `generic` | `/var/www/html/webroot` |
| Craft CMS     | `craftcms/craft`          | Craft 5.11.4                                           | `generic` | `/var/www/html/web`     |
| Statamic      | `statamic/statamic`       | Statamic 6.35.1                                        | `generic` | `/var/www/html/public`  |
| Grav          | `getgrav/grav`            | Grav 2.2.5                                             | `grav`    | `/var/www/html`         |

## Steps every app shares

1. Run `./scripts/hard-reset.sh` if `./app` already has a site in it.
2. Set `CMS` and `DOCROOT` in `.env` to the values in the table.
3. Run `docker compose up -d`, then open a shell with `docker compose exec cli zsh`.
4. Run `composer-create <package>` with the package from the table.

`composer-create` runs `composer create-project` in a temporary folder inside `./app`, then moves the files into `./app`, because Composer will not create a project in a folder that already has files and `./app` always has its `.gitkeep`. Any extra arguments go to Composer, so `composer-create laravel/laravel ^12` installs Laravel 12.

Use these values when an app asks how to reach the other services. The examples in this guide use `app` and `change-me`, which are the database values in `env.example`, so use your own values from `.env` in their place.

| Setting                           | Value                                                           |
| --------------------------------- | --------------------------------------------------------------- |
| Database host                     | `db`                                                            |
| Database port                     | `3306`                                                          |
| Database name, user, and password | `DB_NAME`, `DB_USER`, and `DB_PASSWORD` from `.env`             |
| Redis host and port               | `redis` and `6379`                                              |
| SMTP host and port                | `mailpit` and `1025`, with no username, password, or encryption |
| Site URL                          | `http://localhost:24210`                                        |

The cli container has `DB_NAME`, `DB_USER`, and `DB_PASSWORD` set as environment variables, so commands run there can use `"$DB_NAME"`, `"$DB_USER"`, and `"$DB_PASSWORD"` directly. The php container does not have them, so each app has to store the database values in its own config file.

## Laravel

[Laravel installation docs](https://laravel.com/framework/docs/installation)

```sh
composer-create laravel/laravel
```

Laravel creates `./app/.env` and starts out using SQLite. To use MariaDB, Redis, and Mailpit, change these lines in `./app/.env` and remove the `#` from the `DB_` lines:

```ini
APP_URL=http://localhost:24210
DB_CONNECTION=mariadb
DB_HOST=db
DB_PORT=3306
DB_DATABASE=app
DB_USERNAME=app
DB_PASSWORD=change-me
REDIS_HOST=redis
MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
```

`REDIS_HOST` only tells Laravel where Redis is. To keep the cache or sessions in Redis, also set `CACHE_STORE=redis` or `SESSION_DRIVER=redis`. Then create the tables:

```sh
php artisan migrate
```

The CLI is `php artisan`, and `php artisan test` runs the test suite, which uses an in-memory SQLite database by default.

## Symfony

[Symfony setup docs](https://symfony.com/doc/current/setup.html)

```sh
composer-create symfony/skeleton
```

`symfony/skeleton` installs a minimal app, so run `composer require webapp` after it to add Twig, Doctrine, forms, security, and the other packages a full website uses. To add only the database layer, run `composer require symfony/orm-pack`.

Put the database and mail settings in `./app/.env.local`, which Symfony reads after `.env`:

```ini
DATABASE_URL="mysql://app:change-me@db:3306/app?serverVersion=12.3.3-MariaDB&charset=utf8mb4"
MAILER_DSN=smtp://mailpit:1025
```

The `DATABASE_URL` format is `mysql://USER:PASSWORD@db:3306/DATABASE`. Check the connection with:

```sh
php bin/console dbal:run-sql "SELECT VERSION()"
```

Until you add a route for `/`, the home page shows the "Welcome to Symfony" page with a 404 status. The CLI is `php bin/console`.

## CodeIgniter 4

[CodeIgniter Composer install docs](https://codeigniter.com/user_guide/installation/installing_composer.html)

```sh
composer-create codeigniter4/appstarter
```

CodeIgniter ships an example settings file named `env`. Create `./app/.env` with these lines:

```ini
CI_ENVIRONMENT = development
app.baseURL = 'http://localhost:24210/'
database.default.hostname = db
database.default.database = app
database.default.username = app
database.default.password = change-me
database.default.DBDriver = MySQLi
database.default.port = 3306
email.protocol = smtp
email.SMTPHost = mailpit
email.SMTPPort = 1025
```

Then run the migrations:

```sh
php spark migrate
```

The CLI is `php spark`.

## CakePHP

[CakePHP installation docs](https://book.cakephp.org/5.x/installation.html)

```sh
composer-create cakephp/app
```

Open `./app/config/app_local.php`. Under `Datasources`, then `default`, set:

- `host` to `db`
- `username`, `password`, and `database` to the values from `.env`

Under `EmailTransport`, then `default`, set `host` to `mailpit` and `port` to `1025`.

The welcome page at http://localhost:24210 says "CakePHP is able to connect to the database." when the settings are right. The CLI is `bin/cake`.

## Craft CMS

[Craft CMS installation docs](https://craftcms.com/docs/5.x/install.html)

```sh
composer-create craftcms/craft
```

Save the database settings to `./app/.env`:

```sh
php craft setup/db-creds --interactive=0 --driver=mysql --server=db --port=3306 \
	--database="$DB_NAME" --user="$DB_USER" --password="$DB_PASSWORD"
```

Then install Craft. It asks for the admin email, username, and password, the site name, and the site URL, which is `http://localhost:24210`.

```sh
php craft install/craft
```

The control panel is at http://localhost:24210/admin. To send mail to Mailpit, go to Settings, then Email, choose the SMTP transport, and enter host `mailpit` and port `1025`. The CLI is `php craft`.

## Statamic

[Statamic local install docs](https://statamic.dev/getting-started/installing/local)

```sh
composer-create statamic/statamic
```

Statamic is built on Laravel and keeps its content in files, so it runs without MariaDB. In `./app/.env`, set `APP_URL=http://localhost:24210` and the same `MAIL_` lines as Laravel. To keep users and Laravel's own tables in MariaDB, also set the same `DB_` lines as Laravel and run `php artisan migrate`.

Create the first control panel user, and answer yes when `make:user` asks whether the user is a super user.

```sh
php please make:user
```

The control panel is at http://localhost:24210/cp. The CLI is `php please`, and `php artisan` also works.

## Grav

[Grav installation docs](https://learn.getgrav.org/2/basics/installation)

Grav keeps its content, config, and accounts in Markdown and YAML files under `user`, all inside its document root. In testing, the generic template served page Markdown files under `user/pages` and the `bin/grav` script as plain text, so Grav has its own template, `docker/nginx/grav.conf.template`. `grav.conf.template` follows the `webserver-configs/nginx.conf` file that ships with Grav and blocks:

- the `cache`, `bin`, `logs`, `backup`, `tmp`, and `tests` folders
- `user/config` and `user/accounts`
- Markdown, YAML, Twig, JSON, and script files under `user`, `system`, and `vendor`

Set `CMS=grav` and `DOCROOT=/var/www/html`, then run:

```sh
composer-create getgrav/grav
bin/gpm install admin2
```

Grav does not use a database. `admin2` is the admin plugin for Grav 2, and after it is installed you create the first admin account at http://localhost:24210/admin. The CLIs are `bin/grav` and `bin/gpm`.

## Adding a template for another app

Compose loads `docker/nginx/<CMS>.conf.template`, where `<CMS>` is the `CMS` value in `.env`. These steps give an app its own NGINX rules:

1. Copy `docker/nginx/generic.conf.template` to `docker/nginx/<name>.conf.template`.
2. Add the app's rules. Many apps ship an example NGINX config, as Grav does.
3. Set `CMS=<name>` in `.env` and run `docker compose up -d nginx`.

If `CMS` names a template that does not exist, `docker compose up` stops with a "bind source path does not exist" error.

The generic template blocks:

- the `vendor` and `node_modules` folders
- Composer, npm, pnpm, Yarn, and PHPUnit files
- YAML, Twig, NEON, INI, and `.env` files

Every app in the table above except Grav serves only its `public`, `web`, or `webroot` folder, so the rest of the project is not reachable from the browser. An app that serves its whole project folder, as Grav does, needs its own template.

## Apps that were tried and left out

- **Concrete CMS**: `composer create-project concrete5/composer` fails because `concrete5/core` 9.2.0 through 9.5.5 require `league/flysystem` 1.x or `symfony/yaml` 4.x. Composer blocks those versions because they have published security advisories. Installing it means turning off Composer's advisory blocking.
- **Slim**: on 2026-10-07, `slim/slim-skeleton` installed a PHP-DI version that triggered deprecation notices on PHP 8.4. The skeleton's error handler turned those notices into a 500 error on every page.
