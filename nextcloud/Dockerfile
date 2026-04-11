# Custom Nextcloud image with RAR support
# Based on the official Nextcloud Apache image
FROM nextcloud:30-apache

LABEL maintainer="gi99lin@yandex.ru"
LABEL description="Nextcloud with RAR/7z archive support"

# Install the RAR PHP extension from source (remicollet fork) for PHP 8.x compatibility
# Note: The official PECL version (4.2.0) is broken on PHP 8.3
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        p7zip \
        p7zip-full \
    && git clone https://github.com/remicollet/php-rar.git /usr/src/php/ext/rar \
    && docker-php-ext-install rar \
    && rm -rf /usr/src/php/ext/rar \
    && apt-get purge -y git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

