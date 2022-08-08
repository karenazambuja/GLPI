# syntax=docker/dockerfile:1
FROM ubuntu:20.04

LABEL maintainer="sistemas@unisuam.edu.br"

# Default argument when not provided in the --build-arg environment=production
ARG environment=production

ENV DEBIAN_FRONTEND=noninteractive
ENV PHP_VERSION=8.0

RUN apt-get update && apt-get install -y --no-install-recommends \
	curl \
    cron \
    wget \
	unzip \        
    zip \    
	ca-certificates \
	apt-transport-https \
	software-properties-common \
	language-pack-en-base \
	supervisor \
	nginx \
    php-cas \
    jq \
    libldap-2.4-2 \
    libldap-common \
    libsasl2-2 \
    libsasl2-modules \
    libsasl2-modules-db \
    && rm -rf /var/lib/apt/lists/*

# Permission policy setting
RUN printf '#!/bin/sh\nexit 0' > /usr/sbin/policy-rc.d

# Curl certtificates configs
RUN curl -L -o /etc/ssl/certs/cacert.pem https://curl.haxx.se/ca/cacert.pem && \
    mkdir -p /etc/pki/tls/certs/ && \
    ln -s /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt


###############################################################
# NGINX
###############################################################

# Setting the www-data group ID to 1000 and www-data user ID to 1000
RUN groupmod -g 1000 www-data && usermod -u 1000 -g 1000 www-data

# Changing keepalive_timeout config
RUN sed -i 's/keepalive_timeout.*/keepalive_timeout 600;/' /etc/nginx/nginx.conf

# ADD client_max_body_size config after keepalive_timeout config
RUN sed -i '/keepalive_timeout.*/a \\tclient_max_body_size 60M;' /etc/nginx/nginx.conf

# Uncommenting server_tokens config to hide nginx version
# RUN sed -i 's/# server_tokens.*/server_tokens off;/' /etc/nginx/nginx.conf

# ADD add_header X-Frame-Options config after server_tokens config
# RUN sed -i '/server_tokens.*/a \\tadd_header X-Frame-Options SAMEORIGIN;' /etc/nginx/nginx.conf

# Nginx config to read PHP files
COPY root/etc/nginx/sites-available/default.conf /etc/nginx/sites-available/default
COPY root/etc/nginx/unisuam/general.conf /etc/nginx/unisuam/general.conf
COPY root/etc/nginx/unisuam/security.conf /etc/nginx/unisuam/security.conf


###############################################################
# PHP
###############################################################

# ADD PHP Repository and install extensions
RUN LC_ALL=en_US.UTF-8 add-apt-repository -y ppa:ondrej/php && \
    LC_ALL=en_US.UTF-8 add-apt-repository -y ppa:ondrej/nginx-mainline && \
    apt-get update && apt-get install -y --no-install-recommends \
	php${PHP_VERSION} \
	php${PHP_VERSION}-fpm \
	php${PHP_VERSION}-cli \
    php${PHP_VERSION}-curl \ 
    php${PHP_VERSION}-fileinfo \    
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-mysqli \
    php${PHP_VERSION}-simplexml \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-ldap \
    php${PHP_VERSION}-xmlrpc \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-xmlrpc \
    php${PHP_VERSION}-imap \    
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-bz2 \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-xsl \
    && mkdir -p /run/php \
    && mkdir -p /var/www \
    && rm -rf /var/lib/apt/lists/*

COPY root/etc/php/${PHP_VERSION}/fpm/conf.d/40-unisuam-php.ini /etc/php/${PHP_VERSION}/fpm/conf.d/

COPY root/var/www/index.php /var/www/index.php


###############################################################
# Supervisor
###############################################################

# Supervisor config
RUN	rm /etc/supervisor/conf.d/* 2> /dev/null || true
COPY root/etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
RUN ln -s /etc/supervisor/supervisord.conf /etc/supervisord.conf
COPY root/etc/supervisor/conf.d/nginx.conf /etc/supervisor/conf.d/nginx.conf
COPY root/etc/supervisor/conf.d/php-fpm8.conf /etc/supervisor/conf.d/php-fpm8.conf

###############################################################
# Development environment
###############################################################

RUN if [ "${environment}" = "development" ] ; then \
    apt-get update && apt-get install -y --no-install-recommends \
    nano \
    htop \
    git \
    php${PHP_VERSION}-xdebug && \
    XDEBUG_FILE="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini" && \
    mkdir -p /var/log/xdebug/ && \
    echo "; Setting xdebug configuration for MacOS and Linux:" >> ${XDEBUG_FILE} && \
    echo "xdebug.mode=debug,develop" >> ${XDEBUG_FILE} && \
    echo "xdebug.start_with_request=trigger" >> ${XDEBUG_FILE} && \
    echo "xdebug.client_host=host.docker.internal" >> ${XDEBUG_FILE} && \
    echo "xdebug.discover_client_host=on" >> ${XDEBUG_FILE} && \
    echo "xdebug.log_level = 3" >> ${XDEBUG_FILE} && \
    echo "xdebug.log=/var/log/xdebug/xdebug.log" >> ${XDEBUG_FILE} && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer selfupdate --2 \
    ; fi

###############################################################
# Clean up
###############################################################
RUN rm -rf /tmp/pear \
    && apt-get update && apt-get purge -y --auto-remove unzip gcc make autoconf libc-dev zlib1g-dev pkg-config 2> /dev/null  \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# Copy Docker Entrypoint
COPY root/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80
EXPOSE 443

CMD ["/start.sh"]

WORKDIR /var/www

VOLUME ["/var/www"]
