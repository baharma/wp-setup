# Reuse WordPress' official files and PHP extensions, but run them on the
# patched PHP runtime. PHP 8.3 patch releases keep the same extension API.
FROM wordpress:6-php8.3-apache AS wordpress_source

FROM php:8.3.36-apache-bookworm

# Runtime libraries for the extensions shipped by the official WordPress image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ghostscript \
        libavif15 \
        libfreetype6 \
        libicu72 \
        libjpeg62-turbo \
        libmagickwand-6.q16-6 \
        libpng16-16 \
        libwebp7 \
        libzip4 \
    && rm -rf /var/lib/apt/lists/*

# Keep WordPress' official Apache setup, PHP extensions, defaults, and entrypoint.
COPY --from=wordpress_source /etc/apache2/ /etc/apache2/
COPY --from=wordpress_source /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=wordpress_source /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=wordpress_source /usr/src/wordpress/ /usr/src/wordpress/
COPY --from=wordpress_source /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN ln -svfT docker-entrypoint.sh /usr/local/bin/docker-ensure-installed.sh

VOLUME /var/www/html
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
