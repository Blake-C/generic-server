#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIRM_WORD='reset'
RESET_DIRS=(app data/mariadb data/xdebug)

RED=$'\033[1;31m'
YELLOW=$'\033[1;33m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

fail() {
	printf '%s%s%s\n' "$RED" "$1" "$RESET" >&2
	exit 1
}

if [[ ! -f "$ROOT/compose.yml" || ! -f "$ROOT/docker/cli/functions.zsh" ]]; then
	fail "Refusing to run: $ROOT does not look like the generic-server project."
fi

if [[ ! -t 0 ]]; then
	fail 'Refusing to run: hard-reset needs to be confirmed from an interactive terminal.'
fi

dir_contents() {
	find "$ROOT/$1" -mindepth 1 -maxdepth 1 ! -name .gitkeep
}

dir_size() {
	if [[ -n "$(dir_contents "$1")" ]]; then
		du -sh "$ROOT/$1" | cut -f1
	else
		echo 'empty'
	fi
}

printf '\n%s' "$RED"
printf '  ==============================================================\n'
printf '                 WARNING: HARD RESET CANNOT BE UNDONE\n'
printf '  ==============================================================\n'
printf '%s\n' "$RESET"
printf 'This stops every generic-server container, then permanently deletes:\n\n'
printf '  %s./app%s           (%s)  all site code, uploads, themes, plugins, modules,\n' "$BOLD" "$RESET" "$(dir_size app)"
printf '                          and configuration such as wp-config.php,\n'
printf '                          configuration.php, and settings.php\n'
printf '  %s./data/mariadb%s  (%s)  the entire database: every page, post, user,\n' "$BOLD" "$RESET" "$(dir_size data/mariadb)"
printf '                          and setting\n'
printf '  %s./data/xdebug%s   (%s)  Xdebug profiles and the Xdebug log\n\n' "$BOLD" "$RESET" "$(dir_size data/xdebug)"
printf 'Nothing is moved to the Trash. Any change in ./app that is not committed\n'
printf 'to its own repository or copied elsewhere is lost.\n\n'
printf '%sKept:%s .env, ./data/backups, ./data/pnpm-store, and every .gitkeep file.\n\n' "$YELLOW" "$RESET"
printf 'To keep the database, cancel now and run %sdb-export%s in the cli container first:\n' "$BOLD" "$RESET"
printf '  docker compose exec cli zsh -ic db-export\n\n'

printf 'Type %s%s%s to delete everything listed above, or anything else to cancel: ' "$BOLD" "$CONFIRM_WORD" "$RESET"
answer=''
read -r answer || true

if [[ "$answer" != "$CONFIRM_WORD" ]]; then
	printf '\nCancelled. Nothing was changed.\n'
	exit 0
fi

printf '\nStopping containers...\n'
if ! (cd "$ROOT" && CMS="${CMS:-wordpress}" docker compose down --remove-orphans); then
	fail 'docker compose down failed, so nothing was deleted. Start Docker Desktop and run hard-reset again.'
fi

for dir in "${RESET_DIRS[@]}"; do
	target="$ROOT/$dir"
	[[ -d "$target" ]] || continue
	printf 'Deleting the contents of ./%s\n' "$dir"
	chmod -R u+w "$target"
	find "$target" -mindepth 1 -maxdepth 1 ! -name .gitkeep -exec rm -rf {} +
	touch "$target/.gitkeep"
done

printf '\n%sHard reset complete.%s Set CMS and DOCROOT in .env, then run:\n' "$BOLD" "$RESET"
printf '  docker compose up -d\n'
printf '  docker compose exec cli zsh -ic cms-install\n'
