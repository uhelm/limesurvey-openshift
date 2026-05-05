FROM postgres:17.5

# Claim ownership for the www-data user
RUN chown -R www-data:www-data /var/run/postgresql

RUN mkdir -p /docker-entrypoint-initdb.d

# Set the default working directory
WORKDIR /var/lib/postgresql