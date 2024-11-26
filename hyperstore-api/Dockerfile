FROM dunglas/frankenphp
 
RUN install-php-extensions \
    pcntl xml curl pdo pdo_mysql mysqli opcache
 
COPY . .

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install all project dependencies
RUN composer install --optimize-autoloader

# Configure PHP-FPM and FrankenPHP settings
COPY php.ini /usr/local/etc/php/php.ini

# Configure OPcache
COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Configure Caddy
COPY Caddyfile /etc/caddy/Caddyfile

# All steps in one docker command for convenience - check DM, migrate DB, add tokens, tail logs and 
# start octane server
# 
# Hint - To check env variables add
# echo '=== Environment Variables ===' && env | sort && echo '=== End Environment Variables ===' &&
# at the beginning
#
CMD ["/bin/bash", "-c", "php artisan db:monitor && \
    php artisan migrate --force && \
    php artisan db:seed --force && \
    (tail -f /app/storage/logs/laravel.log & \
    php artisan octane:start --server=frankenphp \
    --host=0.0.0.0 \
    --port=80 \
    --admin-port=8090 \
    --workers=8 \
    --max-requests=2000)"]