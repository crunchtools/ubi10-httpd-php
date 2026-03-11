# ubi10-httpd-php Constitution

> **Version:** 2.0.0
> **Ratified:** 2026-03-10
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.0.0
> **Profile:** Container Image

UBI 10 PHP 8.3 runtime layer. Inherits Apache httpd from ubi10-httpd and troubleshooting tools from ubi10-core. Does NOT include any database server — use ubi10-httpd-php-mariadb or ubi10-httpd-php-postgres leaf images for database workloads.

---

## License

AGPL-3.0-or-later

## Versioning

Follow Semantic Versioning 2.0.0. MAJOR/MINOR/PATCH.

## Base Image

`quay.io/crunchtools/ubi10-httpd:latest` — inherits httpd (enabled), troubleshooting tools (iputils, bind-utils, net-tools, less), cron, procps-ng, diffutils, and systemd hardening.

## Registry

Published to `quay.io/crunchtools/ubi10-httpd-php`.

## RHSM Registration

Not required. All PHP packages are available in UBI repos.

## Containerfile Conventions

- Uses `Containerfile` (not Dockerfile)
- Required LABELs: `maintainer`, `description`
- `dnf install -y` followed by `dnf clean all`
- No RHSM registration needed
- systemd services enabled: php-fpm
- Inherits from parent chain: httpd (enabled), systemd-remount-fs/systemd-update-done/systemd-udev-trigger (masked)
- Inherits `STOPSIGNAL SIGRTMIN+3` and `ENTRYPOINT ["/sbin/init"]` from ubi10-core

## Packages Installed

php, php-mysqlnd, php-xml, php-mbstring, php-intl, php-gd, php-opcache, php-pecl-apcu

Inherited from ubi10-httpd: httpd
Inherited from ubi10-core: iputils, bind-utils, net-tools, less, cronie, procps-ng, diffutils

## Testing

- **Build test**: CI builds the image on every push to main/master
- **Smoke tests**: Service health (httpd, php-fpm), PHP functional (phpinfo via Apache), PHP modules (mysqlnd, mbstring, xml, intl, gd), negative assertion (mariadb-server NOT installed), package integrity, inherited package verification
- **Security scan**: Recommended (not yet implemented)

## Quality Gates

1. Build — CI builds the Containerfile successfully
2. Test — smoke tests pass (services up, PHP works, no MariaDB, packages present)
3. Push — image published only after tests pass
4. Weekly rebuild — cron job picks up base image updates every Monday 4:30 AM UTC

## Downstream Images

ubi10-httpd-php-mariadb, ubi10-httpd-php-postgres (direct children). Changes cascade via repository_dispatch.
