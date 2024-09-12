FROM php:8.1-alpine

# Install system dependencies
RUN apk add --no-cache \
    libzip-dev \
    zip \
    unzip \
    autoconf \
    gcc \
    g++ \
    make \
    && pecl install redis \
    && docker-php-ext-install pdo zip \
    && docker-php-ext-enable redis

# Install PHP extensions
RUN docker-php-ext-install pdo zip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy Laravel files
COPY . .

# Install dependencies
RUN composer install

# Log all laravel logs also in stdout so we can capture them (e.g. via Cloudwatch) and start the PHP server
CMD tail -f /var/www/storage/logs/laravel.log & php artisan serve --host=0.0.0.0 --port=80

# Debug - make sure container does not die
#CMD ["sleep", "infinity"]