FROM php:8.3-fpm-bookworm

ENV ROOT_DIR="/var/www/html"
ENV RELEASE="7.0.0-beta2+260415.zip"

RUN DEBVERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1) \
    && curl -sSL -o /tmp/packages-microsoft-prod.deb https://packages.microsoft.com/config/debian/${DEBVERSION}/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb

# PHP Core Extensions
RUN apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 \
    # && ACCEPT_EULA=Y apt-get install -y mssql-tools18 \
    && apt-get install --no-install-recommends -y \
    curl \
    gnupg2 \
    freetds-dev \
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
    odbcinst \
    postgresql-client \
    pv \
    unixodbc-dev \
    unzip \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pecl install memcached-3.4.0 \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd intl ldap pdo_pgsql zip \
    && pecl install imap pdo_sqlsrv \
    && docker-php-ext-enable imap pdo_sqlsrv \
    && docker-php-ext-enable memcached

ARG DEBUG_BUILD=true

# Add debugging tools into builds if enabled
RUN if [ ${DEBUG_BUILD} = true ]; then \
  apt update && apt-get install --no-install-recommends -y jq vim procps iputils-ping less; \
fi
    
# Copy the LimeSurvey download script into the image
COPY limesurvey-init.sh /usr/local/bin/limesurvey-init.sh
RUN chmod +x /usr/local/bin/limesurvey-init.sh

RUN mkdir -p /var/www/html/

RUN echo "LimeSurvey not found, downloading..." && \
    curl -L "https://download.limesurvey.org/latest-develop-major/limesurvey${RELEASE}" -o /tmp/limesurvey.zip && \
    unzip -o /tmp/limesurvey.zip -d "$ROOT_DIR" | pv -lf -s "$(unzip -l /tmp/limesurvey.zip | wc -l)" > /dev/null && \
    rm -f /tmp/limesurvey.zip && \
    echo "LimeSurvey downloaded and extracted."

RUN chmod 777 "$ROOT_DIR/limesurvey/application/config/"

ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php-fpm"]