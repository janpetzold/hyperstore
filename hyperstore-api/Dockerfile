FROM dunglas/frankenphp
 
RUN install-php-extensions \
    pcntl xml curl redis sqlite3 opcache
 
COPY . .

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install all project dependencies
RUN composer install

# Configure OPcache (optional)
COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# TODO: All steps in here, can this be improved? I mean, it works...
#
# 1. Migrate database (needed e.g. for Passport)
# 2. Tail the laravel.log so we can see it in Cloudwatch
# 3. Start Octane with Frankenphp on port 80
# 
CMD ["/bin/bash", "-c", "php artisan migrate && tail -f /app/storage/logs/laravel.log & php artisan octane:start --server=frankenphp --host=0.0.0.0 --port=80 --admin-port=8090"]