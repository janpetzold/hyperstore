<?php

use Illuminate\Support\Str;

$defaultRedisConfig = [
    'host' => env('REDIS_HOST', '127.0.0.1'),
    'password' => env('REDIS_PASSWORD', null),
    'port' => env('REDIS_PORT', 6379),
    'timeout' => 10,
    'read_timeout' => 5,
    'retry_interval' => 200,
    'persistent' => true,
    'parameters' => [  // Predis specific configuration
        'read_write_timeout' => 0,  // Set to 0 for no timeout
    ],
    'options' => [
        'cluster' => false,
        'parameters' => [
            'password' => env('REDIS_PASSWORD', null),
        ],
        'replication' => false,
    ]
];

return [

    /*
    |--------------------------------------------------------------------------
    | Default Database Connection Name
    |--------------------------------------------------------------------------
    |
    | Here you may specify which of the database connections below you wish
    | to use as your default connection for all database work. Of course
    | you may use many connections at once using the Database library.
    |
    */

    'default' => env('DB_CONNECTION', 'mysql'),

    /*
    |--------------------------------------------------------------------------
    | Database Connections
    |--------------------------------------------------------------------------
    |
    | Here are each of the database connections setup for your application.
    | Of course, examples of configuring each database platform that is
    | supported by Laravel is shown below to make development simple.
    |
    |
    | All database work in Laravel is done through the PHP PDO facilities
    | so make sure you have the driver for your particular database of
    | choice installed on your machine before you begin development.
    |
    */

    /*
    |--------------------------------------------------------------------------
    | Redis Databases
    |--------------------------------------------------------------------------
    |
    | Redis is an open source, fast, and advanced key-value store that also
    | provides a richer body of commands than a typical key-value system
    | such as APC or Memcached. Laravel makes it easy to dig right in.
    |
    */

    'connections' => [
        // MySQL configuration for Passport
        'mysql' => [
            'driver' => 'mysql',
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => env('DB_DATABASE', 'passportdb'),
            'username' => env('DB_USERNAME', 'passport'),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => extension_loaded('pdo_mysql') ? array_filter([
                PDO::MYSQL_ATTR_SSL_CA => env('MYSQL_ATTR_SSL_CA'),
                PDO::ATTR_PERSISTENT => true,                // Enable persistent connections
                PDO::ATTR_EMULATE_PREPARES => true,         // Emulate prepared statements
                PDO::MYSQL_ATTR_USE_BUFFERED_QUERY => true, // Use buffered queries
                PDO::ATTR_STATEMENT_CLASS => false,         // Disable statement class fetching
            ]) : [],
        ],
    ],

    'redis' => [
        // Redis for our actual application data
        'client' => env('REDIS_CLIENT', 'predis'),

        'default' => array_merge($defaultRedisConfig, [
            'database' => env('REDIS_DB', 0),
        ]),

        'requestlog' => array_merge($defaultRedisConfig, [
            'database' => env('REDIS_REQUESTLOG_DB', 1),
        ]),

        'inventory' => array_merge($defaultRedisConfig, [
            'database' => env('REDIS_INVENTORY_DB', 2),
        ]),
    ],

    // Needed because of https://stackoverflow.com/a/55510626/675454
    'fetch' => PDO::FETCH_CLASS, // Returns DB objects in an array format.
    'migrations' => 'migrations'

];
