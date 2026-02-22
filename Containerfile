FROM registry.access.redhat.com/ubi10/ubi-init:latest

LABEL maintainer="fatherlinux <scott.mccarty@crunchtools.com>"
LABEL description="UBI 10 base image with Apache httpd, MariaDB, and PHP 8.3 for WordPress hosting"

# Register with RHSM to access full RHEL repos
ARG RHSM_ACTIVATION_KEY
ARG RHSM_ORG_ID
RUN subscription-manager register --activationkey="$RHSM_ACTIVATION_KEY" --org="$RHSM_ORG_ID"

# Install packages - PHP 8.3 is default in RHEL 10
RUN dnf install -y \
    httpd \
    mariadb-server \
    mariadb \
    php \
    php-mysqlnd \
    php-json \
    php-xml \
    php-mbstring \
    php-intl \
    php-gd \
    php-opcache \
    php-pecl-apcu \
    cronie \
    procps-ng \
    diffutils \
    && dnf clean all

# Unregister to avoid leaking entitlements in the image
RUN subscription-manager unregister

# Enable services
RUN systemctl enable httpd mariadb

# Disable unnecessary systemd services for container
RUN systemctl mask systemd-remount-fs.service \
    systemd-update-done.service \
    systemd-udev-trigger.service

STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/sbin/init"]
CMD ["/sbin/init"]
