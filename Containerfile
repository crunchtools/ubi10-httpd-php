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

# CrunchTools: bound the php-fpm worker pool to fit the container memory limit.
# Prevents the OOM that took crunchtools.com down on 2026-05-27 (stock pm.max_children=50).
COPY config/zz-crunchtools-tuning.conf /etc/php-fpm.d/zz-crunchtools-tuning.conf

# CrunchTools: self-heal php-fpm on failure via systemd drop-in.
COPY config/php-fpm-restart.conf /etc/systemd/system/php-fpm.service.d/restart.conf
