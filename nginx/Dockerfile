FROM nginx:1.29

ENV ROOT_DIR="/var/www/html"
ENV RELEASE="${LIMESURVEY_RELEASE:-6.17.0+260421.zip}"

# Install the GNU Compiler Collection
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl pv unzip \
    && apt-get dist-upgrade -y \
    #&& apt-get install -y gcc mono-mcs \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/nginx/conf.d/default.conf \
    # Create the necessary directories
    && mkdir -p /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/scgi_temp \
    /var/cache/nginx/uwsgi_temp

# Copy the NGINX configuration files
COPY nginx.pid /var/log/nginx
COPY nginx.conf /etc/nginx
RUN mkdir -p /var/www/html/

RUN echo "Checking for LimeSurvey installation..." && \
    echo "Downloading LimeSurvey..." && \
    rm -rf "$ROOT_DIR/limesurvey" && \
    curl -L "https://download.limesurvey.org/latest-master/limesurvey${RELEASE}" -o /tmp/limesurvey.zip && \
    echo "Download completed, extracting... (this may take a moment)" && \
    unzip -o /tmp/limesurvey.zip -d "$ROOT_DIR" | pv -lf -s "$(unzip -l /tmp/limesurvey.zip | wc -l)" > /dev/null && \
    echo "Unzip completed, cleaning up..." && \
    rm -f /tmp/limesurvey.zip && \
    echo "LimeSurvey downloaded and extracted.";

# Claim ownership for the NGiNX user
RUN chown -R nginx:nginx /usr/share/nginx /var/log/nginx /var/cache/nginx /var/www/html /etc/nginx \
    && chmod 777 /var/log/nginx/nginx.pid
USER nginx