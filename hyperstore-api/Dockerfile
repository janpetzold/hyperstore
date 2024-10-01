FROM dunglas/frankenphp
 
RUN install-php-extensions \
    pcntl xml curl redis sqlite3
 
COPY . .

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install all project dependencies
RUN composer install

# Log all laravel logs also in stdout so we can capture them (e.g. via Cloudwatch) and start the PHP server with Frankenphp
CMD ["/bin/bash", "-c", "tail -f /app/storage/logs/laravel.log & php artisan octane:start --server=frankenphp --host=0.0.0.0 --port=80 --admin-port=8090"]