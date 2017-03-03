FROM ubuntu:trusty

MAINTAINER Michel Perez <michel.perez@mobilerider.com>

LABEL version="2.0.1"
LABEL php-version="7.1"

ARG environment=production
ARG time_zone=America/Denver
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
        supervisor

# Add repository
RUN PPAPHP7=" ppa:ondrej/php" && \
    export LC_ALL=en_US.UTF-8 && \
    export LANG=en_US.UTF-8 && \
    add-apt-repository $PPAPHP7 \
    && apt-get update

# Install packages
RUN apt-get -y install \
        php7.1 \
        php7.1-common \
        php7.1-dom \
        php7.1-fpm \
        php7.1-mbstring \
        php7.1-mcrypt \
        php7.1-mysql \
        php7.1-pdo \
        php7.1-xml \
        php7.1-phar \
        php7.1-json \
        php7.1-gd \
        php7.1-curl \
        php7.1-bcmath \
        php7.1-soap \
        php7.1-zip \
        php7.1-geoip \
        php-memcached \
        php-redis

# clear apt cache and remove unnecessary packages
RUN apt-get autoclean && apt-get -y autoremove

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Install PEAR
RUN curl http://pear.php.net/go-pear.phar --output go-pear.phar && \
    php go-pear.phar

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
    -e "s/^;date.timezone.*/date.timezone = America\/Denver/" \
    -e "s/^memory_limit.*/memory_limit = -1/" \
    -e "s/^max_execution_time.*/max_execution_time = 60/" \
    -e "s/^post_max_size.*/post_max_size = 50M/" \
    -e "s/^upload_max_filesize.*/upload_max_filesize = 50M/" \
    /etc/php/7.1/fpm/php.ini

# Configure php-fpm.ini
RUN sed -i \
    -e "s/^error_log.*/error_log = \/proc\/self\/fd\/2/" \
    -e "s/^access_log.*/access_log = \/proc\/self\/fd\/2/" \
    -e "s/;daemonize\s*=\s*yes/daemonize = no/g" \
    /etc/php/7.1/fpm/php-fpm.conf

# Configure php-fpm worker
RUN sed -i \
    -e "s/;clear_env.*/clear_env = no/g" \
    /etc/php/7.1/fpm/pool.d/www.conf

# Create folder for fpm.sock
RUN mkdir /run/php/

# Add application
RUN mkdir -p /var/www
WORKDIR /var/www

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
