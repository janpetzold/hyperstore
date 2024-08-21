FROM php:8.1-alpine

# Install system dependencies
RUN apk add --no-cache \
    libzip-dev \
    zip \
    unzip \
&& docker-php-ext-install pdo zip

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

# Start the Laravel development server
CMD php artisan serve --host=0.0.0.0 --port=80