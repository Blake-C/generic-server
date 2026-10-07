FROM php:8.4.26-fpm-alpine3.24

ARG XDEBUG_VERSION=3.5.3
ARG REDIS_VERSION=6.3.0
ARG IMAGICK_VERSION=3.8.1

RUN apk upgrade --no-cache \
	&& apk add --no-cache \
		freetype \
		icu-libs \
		imagemagick \
		imagemagick-jpeg \
		imagemagick-webp \
		libjpeg-turbo \
		libpng \
		libwebp \
		libzip \
		msmtp \
	&& apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		linux-headers \
		freetype-dev \
		icu-dev \
		imagemagick-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libwebp-dev \
		libzip-dev \
	&& docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
	&& docker-php-ext-install -j"$(nproc)" \
		bcmath \
		exif \
		gd \
		intl \
		mysqli \
		opcache \
		pdo_mysql \
		zip \
	&& pecl install \
		xdebug-${XDEBUG_VERSION} \
		redis-${REDIS_VERSION} \
		imagick-${IMAGICK_VERSION} \
	&& docker-php-ext-enable xdebug redis imagick \
	&& apk del --no-network .build-deps \
	&& rm -rf /tmp/pear ~/.pearrc

COPY php.ini /usr/local/etc/php/conf.d/zz-generic-server.ini
COPY xdebug.ini /usr/local/etc/php/conf.d/zz-xdebug.ini
COPY opcache.ini /usr/local/etc/php/conf.d/zz-opcache.ini
COPY www.conf /usr/local/etc/php-fpm.d/www.conf
COPY msmtprc /etc/msmtprc

USER www-data
