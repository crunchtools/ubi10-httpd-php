FROM quay.io/crunchtools/ubi10-httpd:latest

LABEL maintainer="fatherlinux <scott.mccarty@crunchtools.com>"
LABEL description="UBI 10 PHP 8.3 runtime layer — inherits Apache httpd from ubi10-httpd"

# All PHP packages available in UBI repos — no RHSM needed
RUN dnf install -y \
      php \
      php-mysqlnd \
      php-xml \
      php-mbstring \
      php-intl \
      php-gd \
      php-opcache \
      php-pecl-apcu \
    && dnf clean all

# Enable php-fpm (httpd inherited and already enabled)
RUN systemctl enable php-fpm
