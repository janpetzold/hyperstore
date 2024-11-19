FROM dunglas/frankenphp
 
RUN install-php-extensions \
    pcntl xml curl redis pdo pdo_mysql mysqli opcache
 
COPY . .

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install all project dependencies
RUN composer install

# Configure OPcache (optional)
COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# TODO: All steps in here, can this be improved? I mean, it works...
# 
# Hint - To check env variables add
# echo '=== Environment Variables ===' && env | sort && echo '=== End Environment Variables ===' &&
# at the beginning
#
CMD ["/bin/bash", "-c", "php artisan db:monitor && \
    php artisan migrate --force --verbose && \
    php artisan db:seed --force --verbose && \
    (tail -f /app/storage/logs/laravel.log & \
    php artisan octane:start --server=frankenphp --host=0.0.0.0 --port=80 --admin-port=8090)"]