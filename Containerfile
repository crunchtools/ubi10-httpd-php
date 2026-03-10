FROM registry.access.redhat.com/ubi10/ubi-init:latest

LABEL maintainer="fatherlinux <scott.mccarty@crunchtools.com>"
LABEL description="UBI 10 base image with Apache httpd, MariaDB, and PHP 8.3 for WordPress hosting"

# Register with RHSM, install packages, unregister — single layer so secrets
# are never cached in intermediate layers
RUN --mount=type=secret,id=RHSM_ACTIVATION_KEY \
    --mount=type=secret,id=RHSM_ORG_ID \
    subscription-manager register \
      --activationkey="$(cat /run/secrets/RHSM_ACTIVATION_KEY)" \
      --org="$(cat /run/secrets/RHSM_ORG_ID)" \
    && dnf install -y \
      httpd \
      mariadb-server \
      mariadb \
      php \
      php-mysqlnd \
      php-xml \
      php-mbstring \
      php-intl \
      php-gd \
      php-opcache \
      php-pecl-apcu \
      cronie \
      procps-ng \
      diffutils \
      iputils \
      bind-utils \
      net-tools \
      less \
    && dnf clean all \
    && subscription-manager unregister

# Enable services
RUN systemctl enable httpd mariadb

# Disable unnecessary systemd services for container
RUN systemctl mask systemd-remount-fs.service \
    systemd-update-done.service \
    systemd-udev-trigger.service

STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/sbin/init"]
