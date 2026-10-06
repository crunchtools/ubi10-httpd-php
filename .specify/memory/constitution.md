# ubi10-httpd-php Constitution

> **Version:** 2.1.0
> **Ratified:** 2026-03-10
> **Amended:** 2026-10-02
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.20.0
> **Profile:** Container Image

This file holds what is specific to ubi10-httpd-php. The fleet rules and the Container
Image profile (license, versioning, LABELs, the RHSM secret-mount pattern,
systemd conventions, registry, testing and quality gates) apply at the
inherited version and are checked against this repo's files by
`constitution.yml`. They are not restated here.

## Purpose

UBI 10 PHP 8.3 runtime layer on ubi10-httpd. Published as
`quay.io/crunchtools/ubi10-httpd-php`.

## Parent Image

`quay.io/crunchtools/ubi10-httpd:latest`. It inherits httpd (enabled) and
everything ubi10-core provides. All PHP packages are in the UBI repos; no
RHSM registration.

## Packages and Services

- **Packages:** php, php-mysqlnd, php-xml, php-mbstring, php-intl, php-gd,
  php-opcache, php-pecl-apcu.
- **Enabled:** php-fpm, with a `Restart=on-failure` drop-in
  (`config/php-fpm-restart.conf`).

## php-fpm Pool Bounds

`config/zz-crunchtools-tuning.conf` re-opens the `[www]` pool with
`pm = ondemand`, `pm.max_children = 10`, `pm.process_idle_timeout = 10s` and
`pm.max_requests = 500`. Every PHP image in the tree inherits these bounds;
they exist because of the 2026-05-27 crunchtools.com OOM outage.

## No Database Server

This layer carries no database server. Database workloads use the
ubi10-httpd-php-mariadb or ubi10-httpd-php-postgres leaf images. The smoke
test asserts `mariadb-server` is NOT installed, alongside httpd and php-fpm
active, phpinfo served through Apache, and the mysqlnd, mbstring, xml, intl
and gd modules loaded.

## Downstream Images

Build dispatches `parent-image-updated` to ubi10-httpd-php-mariadb,
ubi10-httpd-php-postgres and spanish.

## History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-03-03 | Initial Container Image profile constitution |
| 1.1.0 | 2026-03-10 | Smoke tests, php-fpm enabled |
| 2.0.0 | 2026-03-10 | Rebased onto ubi10-httpd; MariaDB and RHSM removed |
| 2.0.1 | 2026-09-25 | Gatehouse review, triage and pre-commit gates |
| 2.1.0 | 2026-10-02 | Manifest under constitution v1.18.0: profile restatement removed, image specifics kept |
