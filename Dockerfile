FROM ubuntu:xenial

LABEL version="2.4.0"
LABEL php.version="7.3"

ARG environment=production
ARG time_zone=UTC
ARG nginx_conf=config/nginx/nginx.conf
ARG nginx_site=config/nginx/default.conf
ARG supervisord_conf=config/supervisord/supervisord.conf

ENV APP_ENV=${environment}
ENV APPLICATION_ENV=${environment}
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get -y --no-install-recommends install \
        software-properties-common \
        python-software-properties \
        language-pack-en-base \
        git \
        curl \
        vim \
        zip \
        unzip \
        nginx \
        supervisor \
        apt-utils

# Add repository
RUN PPAPHP7="ppa:ondrej/php" && \
    export LC_ALL=en_US.UTF-8 && \
    export LANG=en_US.UTF-8 && \
    add-apt-repository $PPAPHP7 \
    && apt-get update

# Create folder for fpm.sock
RUN mkdir /run/php/
RUN touch /run/php/php7.3-fpm.sock
RUN chown -R www-data:www-data /run/php/
RUN chmod -R 0660 /run/php/

# Install packages
RUN apt-get -y install \
        php7.3 \
        php7.3-fpm \
        php7.3-common \
        php7.3-dom \
        php7.3-mbstring \
        php7.3-mysql \
        php7.3-pdo \
        php7.3-xml \
        php7.3-phar \
        php7.3-json \
        php7.3-gd \
        php7.3-curl \
        php7.3-bcmath \
        php7.3-soap \
        php7.3-zip \
        php7.3-geoip \
        php7.3-intl \
        php7.3-sqlite3 \
        php-apcu \
        php-memcached \
        php-redis

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash && \
    apt-get -y install nodejs

# Install PEAR (PECL) and dev for extensions
RUN apt-get install -y php-pear php7.3-dev

# Prepare mcrypt install
RUN apt-get -y install gcc make autoconf libc-dev pkg-config \
    libmcrypt-dev

# Allow PECL to parse php.ini by removing -n
# othersise it can't find the required php-xml
# RUN sed -i "$ s|\-n||g" /usr/bin/pecl

# Or require only the XML extension
# pecl needs xml extension and since we build it as shared, it must be
# explicitly declared to be loaded.
#RUN sed -i 's/\$INCARG/& -d extension=xml.so/' \
#    "$pkgdir"/usr/bin/pecl || return 1

# Install mcrypt
RUN /usr/bin/pecl install mcrypt-1.0.2

# clear apt cache and remove unnecessary packages
RUN apt-get autoclean && apt-get -y autoremove

# Install Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"

# Configure Nginx
COPY ${nginx_conf} /etc/nginx/nginx.conf
COPY ${nginx_site} /etc/nginx/sites-enabled/default

# Configure PHP-FPM
# COPY config/php/php.ini /etc/php7.0/conf.d/zzz_custom.ini
# COPY config/php/www.conf /etc/php/7.0/fpm/pool.d/www.conf

# Configure supervisord
COPY ${supervisord_conf} /etc/supervisord.conf

# Configure php.ini
RUN sed -i \
    -e "s/^expose_php.*/expose_php = Off/" \
    -e "s/^;date.timezone.*/date.timezone = ${time_zone}/" \
    -e "s/^memory_limit.*/memory_limit = -1/" \
    -e "s/^max_execution_time.*/max_execution_time = 60/" \
    -e "s/^post_max_size.*/post_max_size = 10M/" \
    -e "s/^upload_max_filesize.*/upload_max_filesize = 10M/" \
    /etc/php/7.3/fpm/php.ini

# Configure php-fpm.ini
RUN sed -i \
    -e "s/^error_log.*/error_log = \/proc\/self\/fd\/2/" \
    -e "s/^access_log.*/access_log = \/proc\/self\/fd\/2/" \
    -e "s/;daemonize\s*=\s*yes/daemonize = no/g" \
    /etc/php/7.3/fpm/php-fpm.conf

# Configure php-fpm worker
RUN sed -i \
    -e "s/;clear_env.*/clear_env = no/g" \
    -e "s/;catch_workers_output.*/catch_workers_output = yes/g" \
    /etc/php/7.3/fpm/pool.d/www.conf

# Enables opcache
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.validate_timestamps=0'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } >> /etc/php/7.3/fpm/conf.d/10-opcache.ini

# Add application
RUN mkdir -p /var/www
WORKDIR /var/www

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
