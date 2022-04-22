FROM php:7.2-apache

LABEL name="Luiz Eduardo Oliveira Fonseca"
LABEL version="201912180545"

ENV COMPOSER_HOME=/root/.composer
ENV SPOOL_THREADS=10
ENV LIMITC=100000
ENV MAUTIC_RUN_CRON_JOBS="true"
ENV CRON_BROADCASTS_SCHEDULE="* * * * *"
ENV MAUTIC_DB_PORT=3306
ENV S3_BUCKET_NAME="backupmauticpowertic"
ENV AWS_ACCESS_KEY_ID=""
ENV AWS_SECRET_ACCESS_KEY=""
ENV AWS_DEFAULT_REGION=""
ENV S3_REGION=""

# ENV MIN_ID
# ENV MAX_ID

# Setting PHP properties
ENV PHP_INI_DATE_TIMEZONE='Europe/Brussels'
ENV PHP_MEMORY_LIMIT=768M
ENV PHP_MAX_UPLOAD=128M
ENV PHP_MAX_EXECUTION_TIME=300

RUN chmod -R +777 /tmp

RUN apt-get update && apt-get upgrade -y && apt-get install -q -y \
  ca-certificates \
  build-essential  \
  software-properties-common \
  htop \
  g++ \
  tcl \
  nano \
  dos2unix \
  git \
  acl \
  gnupg2 \
  dialog \
  zip \
  unzip \
  sudo \
  apache2 \
  libapache2-mod-security2 \
  modsecurity-crs \
  curl \
  tcl \
  cron \
  bzip2 \
  tidy \
  sysvbanner \
  wget \
  htop \
  csstidy \
  zlib1g-dev \
  libjpeg-dev \
  libmagickwand-dev \
  libpng-dev \
  libz-dev \
  libpq-dev \
  libfreetype6-dev \
  libcurl4-openssl-dev \
  libaprutil1-dev \
  libssl-dev \
  libfreetype6-dev \
  libicu-dev \
  libldap2-dev \
  libmemcached-dev \
  libxml2-dev \
  libz-dev \
  libzip-dev \
  mariadb-client \
  libmagickwand-dev \
  imagemagick \
  ghostscript \
  groff \
  python \
  python-setuptools \
  python-pip \
  libmagickwand-dev \
  imagemagick \
  libpng-dev \
  libwebp-dev \
  libjpeg62-turbo-dev \
  libxpm-dev \
  wget \
  groff \
  libmemcached-dev \
  zlib1g-dev \
  libz-dev \
  libmemcachedutil2 \
  libpq-dev \
  libxpm4 \
  libjpeg-dev \
  libjpeg62-turbo \
  libfreetype6-dev \
  python \
  python-setuptools \
  python-pip \
  mariadb-client \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/* \
  && sudo apt-get clean



RUN pip install awscli

RUN docker-php-source extract \
  && docker-php-ext-configure mysqli --with-mysqli=mysqlnd \
  && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
  && docker-php-ext-configure bcmath \
  && docker-php-ext-install bcmath exif intl pcntl ftp mbstring xml gd soap opcache \
  && docker-php-ext-enable opcache  \
  && docker-php-ext-configure gd \
  --with-gd --with-webp-dir --with-jpeg-dir \
  --with-png-dir --with-zlib-dir --with-xpm-dir --with-freetype \
  --enable-gd-native-ttf \
  && docker-php-ext-install gd \
  && for i in $(seq 1 3); do pecl install -o redis && s=0 && break || s=$? && sleep 1; done; (exit $s) \
  && docker-php-ext-enable redis \
  \
  && for i in $(seq 1 3); do echo no | pecl install -o memcached && s=0 && break || s=$? && sleep 1; done; (exit $s) \
  && docker-php-ext-enable memcached \
  && pecl install imagick -y \
  && docker-php-ext-enable imagick

RUN mkdir -p $COMPOSER_HOME \
  && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install GeoIP PHP extension.
RUN apt-get update \
    && apt-get install -y  libgeoip-dev wget \
    && rm -rf /var/lib/apt/lists/* \
    && pecl install geoip-1.1.1 \
    && docker-php-ext-enable geoip

# Install GeoIPUpdate.
RUN apt-get update \
    && apt-get install -y automake autoconf libtool \
    && cd /tmp \
    && wget https://github.com/maxmind/geoipupdate/releases/download/v3.1.0/geoipupdate-3.1.0.tar.gz \
    && tar -xzf geoipupdate-3.1.0.tar.gz \
    && cd geoipupdate-3.1.0 \
    && ./bootstrap \
    && ./configure \
    && make \
    && make install \
    && apt-get purge --auto-remove -y automake autoconf libtool \
    && rm -rf /var/lib/apt/lists/*

RUN { \
  echo 'opcache.memory_consumption=4096M'; \
  echo 'opcache.interned_strings_buffer=16'; \
  echo 'opcache.max_accelerated_files=10000'; \
  echo 'opcache.revalidate_freq=2'; \
  echo 'opcache.fast_shutdown=1'; \
  echo 'opcache.enable_cli=1'; \
  echo 'expose_php = Off'; \
  echo 'file_uploads = On'; \
  echo 'date.timezone = "Europe/Brussels"'; \
  echo 'always_populate_raw_post_data = -1'; \
  echo 'memory_limit = 512M'; \
  echo 'upload_max_filesize = 128M'; \
  echo 'post_max_size = 128M'; \  
  echo 'max_execution_time = 300'; \    
  } > /usr/local/etc/php/conf.d/powertic.ini

#RUN printf "no\n" | pecl install apcu

#RUN pecl install apcu_bc-1.0.3 \
#  && docker-php-ext-enable apcu --ini-name 10-docker-php-ext-apcu.ini \
#  && docker-php-ext-enable apc --ini-name 20-docker-php-ext-apc.ini

RUN a2enmod setenvif \
  headers \
  security2 \
  deflate \
  filter \
  expires \
  rewrite \
  include \
  ext_filter

RUN mkdir -p /var/www/bootstrap

#COPY bin/* /usr/bin/
RUN chmod +x -R /usr/bin/*
RUN chmod +x -R /usr/bin/

RUN rm /etc/cron.d/mautic
RUN rm /etc/crontab

COPY smartoys.crontab /etc/crontab

RUN chmod 644 /etc/crontab

# RUN crontab /etc/crontab

# Create the log file to be able to run tail
RUN touch /var/log/cron.log
RUN chmod 777 /var/log/cron.log


RUN alias console='sudo -Hu www-data php app/console'

COPY docker-entrypoint.sh /entrypoint.sh

EXPOSE 80

RUN ["chmod", "+x", "/entrypoint.sh"]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["apache2-foreground"]
