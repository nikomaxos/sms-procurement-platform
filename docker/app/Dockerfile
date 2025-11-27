FROM php:8.4-fpm

# System packages for PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libicu-dev libonig-dev libzip-dev libpq-dev \
    libjpeg-dev libpng-dev libfreetype6-dev \
 && rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN docker-php-ext-configure intl \
 && docker-php-ext-install intl mbstring zip pdo_pgsql \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install gd

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Permissions helper + sane PHP-FPM
COPY docker/app/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
CMD ["entrypoint.sh"]

# Add Postgres client tools so version_snapshot.sh can run pg_dump from the app container
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*
