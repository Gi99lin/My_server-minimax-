# Custom Nextcloud image with RAR support
# Based on the official Nextcloud Apache image
FROM nextcloud:30-apache

LABEL maintainer="gi99lin@yandex.ru"
LABEL description="Nextcloud with RAR/7z archive support"

# Install the RAR PHP extension via PECL
# This makes the extension persistent across container restarts
RUN pecl install rar \
    && docker-php-ext-enable rar

# Install p7zip for 7z archive support (optional but useful)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        p7zip \
        p7zip-full \
        unrar \
    && rm -rf /var/lib/apt/lists/*
