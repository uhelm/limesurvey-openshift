FROM php:fpm-bookworm

# Copy the LimeSurvey download script into the image
COPY limesurvey-init.sh /usr/local/bin/limesurvey-init.sh
RUN chmod +x /usr/local/bin/limesurvey-init.sh

# Copy the php.ini configuration file
COPY php.ini /usr/local/etc/php

# PHP Core Extensions
RUN apt-get update && apt-get install -y \
    curl \
    libc-client-dev \
    libfreetype-dev \
    libicu-dev \
    libjpeg-dev \
    libkrb5-dev \
    libldap2-dev \
    libmemcached-dev \
    libmemcached-tools \
    libpng-dev \
    libpq-dev \
    libssl-dev \
    libzip-dev \
    memcached \
    postgresql-client \
    pv \
    unzip \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd intl ldap pdo_pgsql zip \
    && pecl install imap \
    && docker-php-ext-enable imap \
    && pecl install memcached-3.3.0 \
    && docker-php-ext-enable memcached

ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php-fpm"]