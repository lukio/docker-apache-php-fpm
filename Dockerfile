FROM debian:bullseye-slim
MAINTAINER Luciano Rossi <lukio@gcoop.coop>

# No tty
ENV DEBIAN_FRONTEND noninteractive
ENV WWW_FOLDER /var/www/html
ENV WWW_USER www-data
ENV WWW_GROUP www-data

# Apache 2.4 + PHP-7.4-FPM
RUN apt-get update \
    # Tools
    && apt-get -y --no-install-recommends install \
        curl \
        ca-certificates \
        vim \
        zip \
        unzip \
        cron \
        telnet \
        iproute2 \
        re2c \
        git \
    # Supervisor
    && apt-get -y --no-install-recommends install \
        supervisor \
    # MySQL Client
    # && apt-get -y --no-install-recommends install \
    #     mariadb-client-10.5 \
    # Install Apache + PHP
    && apt-get -y --no-install-recommends install \
        apache2 \
        php-fpm php7.4-mysql php7.4-xml php7.4-gd php7.4-mbstring php7.4-bcmath \
        php7.4-curl php7.4-cli php7.4-imap php7.4-intl php7.4-json php7.4-ldap \
        php7.4-soap php7.4-zip php-memcache php7.4-opcache php7.4-readline \
        php-xdebug \
    # Configure Apache + PHP
    && a2enconf php7.4-fpm \
    && a2enmod proxy \
    && a2enmod proxy_fcgi \
    && a2enmod rewrite \
    # Clean
    && rm -rf /var/lib/apt/lists/*

WORKDIR "/tmp"

ENV COMPOSER_BINARY=/usr/local/bin/composer \
    COMPOSER_HOME=/usr/local/composer
ENV PATH $PATH:$COMPOSER_HOME

# Instalo composer v1.10.5
# RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
# RUN php -r "if (hash_file('sha384', 'composer-setup.php') === '$(wget -q -O - https://composer.github.io/installer.sig)') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
# RUN php composer-setup.php --1
# RUN php -r "unlink('composer-setup.php');"
# RUN mv composer.phar $COMPOSER_BINARY && chmod +x $COMPOSER_BINARY

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --1

#Cambio TimeZone
RUN ln -sf /usr/share/zoneinfo/America/Argentina/Buenos_Aires /etc/localtime

# Supervisor
RUN mkdir -p /run/php/
COPY ./config/supervisord/supervisord.conf /etc/supervisor/supervisord.conf
COPY ./config/supervisord/conf.d/ /etc/supervisor/conf.d/

# Apache Configuration
COPY ./config/apache/000-default.conf /etc/apache2/sites-available/000-default.conf

# PHP Configuration
COPY ./config/php/fpm/php.ini /etc/php/7.4/fpm/php.ini
COPY ./config/php/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf
COPY ./config/php/fpm/xdebug.ini /etc/php/7.4/mods-available/xdebug.ini

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

RUN rm -rf ${WWW_FOLDER}/*
COPY --chown=${WWW_USER}:${WWW_GROUP} app ${WWW_FOLDER}

WORKDIR /var/www/html
RUN composer install

# Startup script to change uid/gid (if environment variable passed) and start supervisord in foreground
COPY ./scripts/start.sh /start.sh
RUN chmod 755 /start.sh

EXPOSE 80

CMD ["/bin/bash", "/start.sh"]
