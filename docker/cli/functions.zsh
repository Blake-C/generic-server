SERVER_DIR='/var/www/html'
BACKUPS_DIR='/var/www/backups'
STAGING_DIR="$SERVER_DIR/.cms-staging"

alias root="cd $SERVER_DIR"
alias drush="$SERVER_DIR/vendor/bin/drush"
alias joomla="php $SERVER_DIR/cli/joomla.php"

_cms_prompt_admin() {
	read "CMS_SITE_NAME?Site name: "
	read "CMS_ADMIN_USER?Admin username: "
	read "CMS_ADMIN_EMAIL?Admin email: "
	read -s "CMS_ADMIN_PASSWORD?Admin password: "
	echo
}

_cms_clear_admin() {
	unset CMS_SITE_NAME CMS_ADMIN_USER CMS_ADMIN_EMAIL CMS_ADMIN_PASSWORD
}

_cms_table_prefix() {
	echo "$(tr -cd 'a-z' < /dev/urandom | head -c 4)_"
}

_cms_app_is_empty() {
	[[ -z "$(ls -A "$SERVER_DIR" | grep -v '^\.gitkeep$')" ]]
}

_install_wordpress() {
	cd "$SERVER_DIR" || return 1

	wp core download || return 1
	echo "$DB_PASSWORD" | wp config create \
		--dbname="$DB_NAME" \
		--dbuser="$DB_USER" \
		--dbhost="$DB_HOST" \
		--dbprefix="$(_cms_table_prefix)" \
		--dbcharset=utf8mb4 \
		--prompt=dbpass > /dev/null || return 1
	wp config set WP_ENVIRONMENT_TYPE local
	wp config set WP_REDIS_HOST redis

	echo "$CMS_ADMIN_PASSWORD" | wp core install \
		--url="$SITE_URL" \
		--title="$CMS_SITE_NAME" \
		--admin_user="$CMS_ADMIN_USER" \
		--admin_email="$CMS_ADMIN_EMAIL" \
		--skip-email \
		--prompt=admin_password > /dev/null || return 1
	wp rewrite structure '/%postname%/'
}

_install_joomla() {
	local version="${JOOMLA_VERSION:-6.1.4}"
	local package="Joomla_${version}-Stable-Full_Package.tar.gz"
	local url="https://github.com/joomla/joomla-cms/releases/download/${version}/${package}"
	local api="https://api.github.com/repos/joomla/joomla-cms/releases/tags/${version}"
	local archive="/tmp/${package}"
	local expected

	expected=$(curl -fsSL "$api" | php -r '
		$release = json_decode(stream_get_contents(STDIN), true);
		foreach ($release["assets"] ?? [] as $asset) {
			if ($asset["name"] === $argv[1]) {
				echo preg_replace("/^sha256:/", "", $asset["digest"] ?? "");
			}
		}
	' "$package")

	if [[ -z "$expected" ]]; then
		echo "Could not read the SHA-256 digest for $package from GitHub."
		return 1
	fi

	curl -fsSL -o "$archive" "$url" || return 1

	if ! echo "$expected  $archive" | sha256sum -c - > /dev/null; then
		echo "Checksum mismatch for $package. The download was deleted."
		rm -f "$archive"
		return 1
	fi

	tar -xzf "$archive" -C "$SERVER_DIR" || return 1
	rm -f "$archive"

	cd "$SERVER_DIR" || return 1
	php installation/joomla.php install \
		--site-name="$CMS_SITE_NAME" \
		--admin-user="$CMS_ADMIN_USER" \
		--admin-username="$CMS_ADMIN_USER" \
		--admin-password="$CMS_ADMIN_PASSWORD" \
		--admin-email="$CMS_ADMIN_EMAIL" \
		--db-type=mysqli \
		--db-host="$DB_HOST" \
		--db-user="$DB_USER" \
		--db-pass="$DB_PASSWORD" \
		--db-name="$DB_NAME" \
		--db-prefix="$(_cms_table_prefix)" \
		--db-encryption=0 \
		--no-interaction || return 1

	[[ -d "$SERVER_DIR/installation" ]] && rm -rf "$SERVER_DIR/installation"
	return 0
}

_composer_create() {
	rm -rf "$STAGING_DIR"
	composer create-project "$1" "$STAGING_DIR" "${@:2}" --no-interaction || {
		rm -rf "$STAGING_DIR"
		return 1
	}
	rsync -a "$STAGING_DIR/" "$SERVER_DIR/" || return 1
	rm -rf "$STAGING_DIR"
}

composer-create() {
	if [[ $# -eq 0 ]]; then
		echo "Usage: composer-create <package> [version] [composer options]"
		echo "Example: composer-create laravel/laravel"
		return 1
	fi

	if ! _cms_app_is_empty; then
		echo "$SERVER_DIR already has files. Run ./scripts/hard-reset.sh on your Mac first."
		return 1
	fi

	_composer_create "$@" || return 1
	echo "\n$1 is in $SERVER_DIR. Finish its setup with the steps in docs/other-apps.md."
}

_install_drupal() {
	_composer_create drupal/recommended-project || return 1

	cd "$SERVER_DIR" || return 1
	composer require drush/drush --no-interaction || return 1

	vendor/bin/drush site:install standard \
		--db-url="mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:3306/${DB_NAME}" \
		--db-prefix="$(_cms_table_prefix)" \
		--site-name="$CMS_SITE_NAME" \
		--account-name="$CMS_ADMIN_USER" \
		--account-mail="$CMS_ADMIN_EMAIL" \
		--account-pass="$CMS_ADMIN_PASSWORD" \
		--yes || return 1

	chmod u+w web/sites/default web/sites/default/settings.php
	cat >> web/sites/default/settings.php <<-'PHP'

		$settings['trusted_host_patterns'] = ['^localhost$', '^127\.0\.0\.1$'];
		$settings['enable_html5_validation'] = FALSE;
	PHP
	chmod a-w web/sites/default web/sites/default/settings.php
}

cms-install() {
	local working_dir=$(pwd)

	case "$CMS" in
		wordpress|joomla|drupal) ;;
		'')
			echo "Set CMS in .env to wordpress, joomla, drupal, generic, or the name of a template in docker/nginx."
			return 1
			;;
		*)
			echo "cms-install has no installer for CMS=$CMS."
			echo "Install the app into $SERVER_DIR yourself. For an app on Packagist, run:"
			echo "  composer-create <package>"
			echo "docs/other-apps.md has the steps for common PHP apps."
			return 1
			;;
	esac

	if ! _cms_app_is_empty; then
		echo "$SERVER_DIR already has files. Run ./scripts/hard-reset.sh on your Mac first."
		return 1
	fi

	_cms_prompt_admin

	"_install_$CMS"
	local result=$?

	_cms_clear_admin
	cd "$working_dir"

	if [[ $result -eq 0 ]]; then
		echo "\n$CMS is installed at $SITE_URL"
	else
		echo "\n$CMS install failed."
	fi

	return $result
}

db-export() {
	local file="$BACKUPS_DIR/${DB_NAME}_$(date +%Y%m%d%H%M%S).sql.gz"

	MYSQL_PWD="$DB_PASSWORD" mariadb-dump \
		--host="$DB_HOST" \
		--user="$DB_USER" \
		--single-transaction \
		--routines \
		"$DB_NAME" | gzip > "$file" || return 1

	echo "Saved $file"
}

db-import() {
	if [[ ! -f "$1" ]]; then
		echo "Usage: db-import <file.sql|file.sql.gz>"
		return 1
	fi

	if [[ "$1" == *.gz ]]; then
		gunzip -c "$1"
	else
		cat "$1"
	fi | MYSQL_PWD="$DB_PASSWORD" mariadb --host="$DB_HOST" --user="$DB_USER" "$DB_NAME"
}

db-cli() {
	MYSQL_PWD="$DB_PASSWORD" mariadb --host="$DB_HOST" --user="$DB_USER" "$DB_NAME"
}
