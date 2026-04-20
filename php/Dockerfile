FROM php:fpm-bookworm

ENV ROOT_DIR="/var/www/html"
ENV DOWNLOAD_LOCKFILE="$ROOT_DIR/.limesurvey_downloaded" 
ENV RELEASE="${LIMESURVEY_RELEASE:-6.15.5+250724.zip}"

# Copy the LimeSurvey download script into the image
COPY limesurvey-init.sh /usr/local/bin/limesurvey-init.sh
RUN chmod +x /usr/local/bin/limesurvey-init.sh

# Copy the php.ini configuration file
COPY php.ini /usr/local/etc/php

# PHP Core Extensions
RUN apt-get update && apt-get install --no-install-recommends -y \
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
    && pecl install memcached-3.4.0 \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd intl ldap pdo_pgsql zip \
    && pecl install imap \
    && docker-php-ext-enable imap \
    && docker-php-ext-enable memcached

    RUN echo "Checking for LimeSurvey installation..." && \
    if [ ! -f "$DOWNLOAD_LOCKFILE" ]; then \
        echo "LimeSurvey not found, downloading..." && \
        rm -rf "$ROOT_DIR/limesurvey" && \
        curl -L "https://download.limesurvey.org/latest-master/limesurvey${RELEASE}" -o /tmp/limesurvey.zip && \
        echo "Download completed, extracting... (this may take a moment)" && \
        unzip -o /tmp/limesurvey.zip -d "$ROOT_DIR" | pv -lf -s "$(unzip -l /tmp/limesurvey.zip | wc -l)" > /dev/null && \
        echo "Unzip completed, cleaning up..." && \
        rm -f /tmp/limesurvey.zip && \
        touch "$DOWNLOAD_LOCKFILE" && \
        echo "LimeSurvey downloaded and extracted."; \
        else \
        echo "LimeSurvey already present, skipping download."; \
        fi

ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php-fpm"]