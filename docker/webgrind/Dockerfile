FROM php:8.4.26-fpm-alpine3.24 AS source

ARG WEBGRIND_VERSION=1.9.4
ARG WEBGRIND_SHA256=63dcf4b045b996c68f733f980b3493a82d65ef808c24a4b12bd72b80eca46f74

RUN apk add --no-cache g++ make zlib-dev \
	&& curl -fsSL -o /tmp/webgrind.tar.gz "https://github.com/jokkedk/webgrind/archive/refs/tags/v${WEBGRIND_VERSION}.tar.gz" \
	&& echo "${WEBGRIND_SHA256}  /tmp/webgrind.tar.gz" | sha256sum -c - \
	&& mkdir /webgrind \
	&& tar -xzf /tmp/webgrind.tar.gz -C /webgrind --strip-components=1 \
	&& cd /webgrind \
	&& make \
	&& sed -i \
		-e 's/\(^ *\)\/\/\(.*DOCKER:ENABLE\)/\1\2/g' \
		-e "s|static \$profilerDir = '/tmp';|static \$profilerDir = '/profiles';|" \
		-e "s|static \$storageDir = '';|static \$storageDir = '/tmp';|" \
		-e "s|static \$checkVersion = true;|static \$checkVersion = false;|" \
		-e "s|static \$defaultTimezone = 'Europe/Copenhagen';|static \$defaultTimezone = 'America/Chicago';|" \
		config.php \
	&& rm -rf Dockerfile docker-compose.yml package.sh .github

FROM php:8.4.26-fpm-alpine3.24

RUN apk upgrade --no-cache \
	&& apk add --no-cache graphviz python3 libstdc++ zlib

COPY --from=source /webgrind /webgrind

USER www-data
WORKDIR /webgrind
EXPOSE 8080

ENTRYPOINT []
CMD ["php", "-S", "0.0.0.0:8080", "-t", "/webgrind"]
