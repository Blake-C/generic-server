# Coding standards with PHPCS in VS Code

This setup is for the PHP_CodeSniffer extension for VS Code (`obliviousharmony.vscode-php-codesniffer`). Each app in `./app` can use its own PHPCS version and its own rules, and code that has no rules is not checked.

## How the extension finds rules and PHPCS

`.vscode/settings.json` sets two options for this repository:

- `phpCodeSniffer.standard` is `Automatic`. For each file you edit, the extension looks for `.phpcs.xml`, `phpcs.xml`, `.phpcs.xml.dist`, or `phpcs.xml.dist`, starting in that file's folder and moving up one folder at a time until it reaches the workspace root. It uses the first file it finds, so the ruleset closest to the code wins.
- `phpCodeSniffer.autoExecutable` is `true`. The extension looks for `vendor/bin/phpcs` the same way, starting in the file's folder and moving up. If it finds one, it runs that project's PHPCS. If not, it runs the global `phpcs` installed by `digitalblake-system-setup/bootstrap.sh`.

The extension runs PHPCS on your Mac with the Mac's PHP. The php and cli containers are not involved.

## The fallback ruleset

`phpcs.xml.dist` at the root of this repository excludes every file. Any file under `./app` that has no ruleset of its own reaches this one, so the extension checks nothing and reports nothing. Without it, the extension shows "Failed to locate a PHPCS configuration file" for every file in CMS core.

## Where to put an app's ruleset

Put `phpcs.xml.dist` in the folder that holds your own code, and commit it with that code:

| App                                                         | Ruleset location                                                      |
| ----------------------------------------------------------- | --------------------------------------------------------------------- |
| WordPress                                                   | your theme or plugin folder, such as `app/wp-content/themes/my-theme` |
| Drupal                                                      | `app/web/modules/custom` and `app/web/themes/custom`                  |
| Joomla                                                      | your template, component, module, or plugin folder                    |
| Laravel, Symfony, CodeIgniter, CakePHP, Craft CMS, Statamic | `app`                                                                 |

When the ruleset sits in your own folder, CMS core files fall through to the fallback ruleset, so the ruleset does not need patterns to exclude core. The frameworks keep everything under `app` as project code, so their ruleset excludes the folders that hold generated or third-party files instead.

## Why each project brings its own PHPCS

The global PHPCS is version 3.13, with the WordPress, PHPCompatibility, and PSR12 standards. `drupal/coder` 9 requires PHPCS 4, and the WordPress Coding Standards 3.x series runs on PHPCS 3, so one global install cannot serve both. With `autoExecutable` on, a Drupal app that installs `drupal/coder` gets its own PHPCS 4 from `app/vendor/bin/phpcs`, and a WordPress site without a `vendor` folder uses the global PHPCS 3.

## Example rulesets

Each example below was run through PHPCS on 2026-10-07 with sample code, using the same stdin mode the extension uses.

### WordPress

Uses the global PHPCS, so nothing has to be installed. Change `my-theme` to your theme's text domain.

```xml
<?xml version="1.0"?>
<ruleset name="my-theme">
	<rule ref="WordPress"/>
	<config name="testVersion" value="8.4-"/>
	<rule ref="PHPCompatibility"/>
	<rule ref="WordPress.WP.I18n">
		<properties>
			<property name="text_domain" type="array">
				<element value="my-theme"/>
			</property>
		</properties>
	</rule>
</ruleset>
```

### Drupal

Install Coder in the Drupal project from the cli container:

```sh
composer require --dev drupal/coder
```

Drupal's `recommended-project` already allows the `dealerdirect/phpcodesniffer-composer-installer` plugin, which registers the `Drupal` and `DrupalPractice` standards with the project's PHPCS. Put this in `app/web/modules/custom/phpcs.xml.dist`, and the same file in `app/web/themes/custom`:

```xml
<?xml version="1.0"?>
<ruleset name="drupal-custom">
	<arg name="extensions" value="php,module,inc,install,test,profile,theme,info,yml"/>
	<rule ref="Drupal"/>
	<rule ref="DrupalPractice"/>
</ruleset>
```

VS Code only sends a file to the extension when it treats the file as PHP. Add `"files.associations": { "*.module": "php", "*.install": "php", "*.inc": "php", "*.theme": "php", "*.profile": "php" }` to your settings if `.module` and the other Drupal file types do not open as PHP.

### Joomla

Use PSR-12 with the global PHPCS. The `joomla/coding-standards` package on Packagist has had no release since a 2020 release candidate, and that release requires PHPCS 2.x.

```xml
<?xml version="1.0"?>
<ruleset name="my-joomla-extension">
	<rule ref="PSR12"/>
	<config name="testVersion" value="8.4-"/>
	<rule ref="PHPCompatibility"/>
</ruleset>
```

### Laravel and other frameworks

Put this in `app/phpcs.xml.dist`. The exclude patterns cover Laravel's folders, so change them to match the framework, such as `var` for Symfony or `writable` for CodeIgniter.

```xml
<?xml version="1.0"?>
<ruleset name="my-app">
	<exclude-pattern>*/vendor/*</exclude-pattern>
	<exclude-pattern>*/storage/*</exclude-pattern>
	<exclude-pattern>*/bootstrap/cache/*</exclude-pattern>
	<exclude-pattern>*/node_modules/*</exclude-pattern>
	<exclude-pattern>*\.blade\.php$</exclude-pattern>
	<rule ref="PSR12"/>
	<config name="testVersion" value="8.4-"/>
	<rule ref="PHPCompatibility"/>
</ruleset>
```

The global PHPCS has PHPCompatibility. If the framework installs its own PHPCS in `app/vendor`, the extension uses that one instead, so add `phpcompatibility/php-compatibility` to the project with `composer require --dev` or remove the two PHPCompatibility lines.

## PHP version

The extension runs PHPCS with the Mac's PHP 8.5, and the stack runs PHP 8.4. `<config name="testVersion" value="8.4-"/>` makes PHPCompatibility check the code against PHP 8.4 and later, which matches what the site runs on.
