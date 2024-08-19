# Use an official Alpine as a parent image
FROM alpine:3.20

# Install PHP-FPM and other dependencies
RUN apk update
RUN apk --no-cache add \
        php83 \
        php83-ctype \
        php83-curl \
        php83-dom \
        php83-exif \
        php83-fileinfo \
        php83-fpm \
        php83-gd \
        php83-iconv \
        php83-intl \
        php83-json \
        php83-mbstring \
        php83-opcache \
        php83-openssl \
        php83-pecl-apcu \
        php83-pdo \
        php83-phar \
        php83-session \
        php83-simplexml \
        php83-sodium \
        php83-tokenizer \
        php83-xml \
        php83-xmlreader \
        php83-zip \
        php83-zlib \
        nginx \
        runit \
        curl

# Check if www-data user and group exist, then create if they don't
RUN if ! getent group www-data >/dev/null; then \
        addgroup -S www-data; \
    fi && \
    if ! getent passwd www-data >/dev/null; then \
        adduser -S -G www-data www-data; \
    fi

# Copy nginx config
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy application files
COPY . /var/www/html

# Set working directory
WORKDIR /var/www/html

# Install Composer and dependencies
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer install --optimize-autoloader --no-dev

# Set permissions for nginx
RUN chown -R www-data:www-data /var/www/html

# Set permissions for Laravel
RUN mkdir -p /var/www/html/storage/logs
RUN chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Generate application key
RUN php artisan key:generate

# Expose port 80 for Nginx
EXPOSE 80

# Start PHP-FPM and Nginx
CMD ["sh", "-c", "php-fpm83 & nginx -g 'daemon off;'"]
