# ubi10-httpd-php Constitution

> **Version:** 1.1.0
> **Ratified:** 2026-03-10
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.0.0
> **Profile:** Container Image

UBI 10 base image with Apache httpd, PHP 8.3, and MariaDB. Primary use case: hosting WordPress.

---

## License

AGPL-3.0-or-later

## Versioning

Follow Semantic Versioning 2.0.0. MAJOR/MINOR/PATCH.

## Base Image

`registry.access.redhat.com/ubi10/ubi-init:latest` — systemd-based for multi-service containers (httpd + MariaDB).

## Registry

Published to `quay.io/crunchtools/ubi10-httpd-php`.

## RHSM Registration

Uses `--mount=type=secret` for subscription-manager registration to access RHEL repos for packages not available in UBI. Register, install, and unregister happen in a single `RUN` layer so secrets are never cached in intermediate layers.

## Containerfile Conventions

- Uses `Containerfile` (not Dockerfile)
- Required LABELs: `maintainer`, `description`
- `dnf install -y` followed by `dnf clean all`
- `subscription-manager unregister` after package installation
- systemd services enabled: httpd, mariadb
- systemd services masked: systemd-remount-fs, systemd-update-done, systemd-udev-trigger
- `STOPSIGNAL SIGRTMIN+3` for proper systemd shutdown
- `ENTRYPOINT ["/sbin/init"]`

## Packages Installed

httpd, mariadb-server, mariadb, php, php-mysqlnd, php-xml, php-mbstring, php-intl, php-gd, php-opcache, php-pecl-apcu, cronie, procps-ng, diffutils, iputils, bind-utils, net-tools, less

## Testing

- **Build test**: CI builds the image on every push to main/master
- **Smoke tests**: Service health (httpd, mariadb), PHP functional (phpinfo via Apache), package integrity (rpm -q for all packages)
- **Security scan**: Recommended (not yet implemented)

## Quality Gates

1. Build — CI builds the Containerfile successfully
2. Test — smoke tests pass (services up, PHP works, packages present)
3. Push — image published only after tests pass
4. Weekly rebuild — cron job picks up base image updates every Monday 6 AM UTC
