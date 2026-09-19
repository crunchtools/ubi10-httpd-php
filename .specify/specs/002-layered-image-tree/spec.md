# Specification: Layered Image Tree Architecture

> **Spec ID:** 002-layered-image-tree
> **Status:** Draft
> **Version:** 0.1.0
> **Author:** Scott McCarty
> **Date:** 2026-03-10
> **Closes:** [#2](https://github.com/crunchtools/ubi10-httpd-php/issues/2)

> **Superseded in part (2026-09-19, RT #1478):** every reference below to
> `zabbix` / `crunchtools/zabbix` and to Zabbix trapper items is obsolete.
> Zabbix was decommissioned in RT #1459 and replaced by Nagios, so that repo is
> no longer a member of the cascade and the watchdog no longer pushes trapper
> items — it writes `factory-status.json`, which Nagios reads. The text is left
> as written because this is the record of what was designed at the time, not a
> description of the current tree.

## Overview

Re-architect the CrunchTools container image ecosystem from flat, monolithic images into a layered tree. Each layer provides exactly one concern (troubleshooting tools, web server, language runtime, database) and is tested independently. Database servers are pushed to leaf images, creating a clean RHSM boundary: only leaf images with `mariadb-server` or `postgresql-server` need Red Hat subscription access. Every other layer builds from UBI repos alone.

---

## Image Tree

```
ubi10/ubi-init (upstream)
  └── ubi10-core (NO RHSM) — troubleshooting tools, systemd hardening
        └── ubi10-httpd (NO RHSM) — Apache httpd
              ├── proxy (NO RHSM) — + mod_ssl
              ├── ubi10-httpd-php (NO RHSM) — + PHP 8.3, php-fpm
              │     ├── ubi10-httpd-php-mariadb (RHSM) — + MariaDB
              │     └── ubi10-httpd-php-postgres (RHSM) — + PostgreSQL + php-pgsql
              └── ubi10-httpd-perl (NO RHSM) — + mod_fcgid, perl
                    └── ubi10-httpd-perl-mariadb (RHSM) — + MariaDB
```

### Key design decisions

1. **One repo per image.** Each node in the tree is a separate GitHub repo under `crunchtools/`.
2. **RHSM boundary at the leaf.** All packages except `mariadb-server` and `postgresql-server` are available in UBI repos. Only database leaf images need RHSM registration.
3. **No database in language runtime images.** `ubi10-httpd-php` and `ubi10-httpd-perl` ship zero database servers. Sites that need a database use the `-mariadb` or `-postgres` leaf image. Static sites use the slimmer runtime image directly.
4. **Consistent split across PHP and Perl trees.** Both language runtime images follow the same pattern: runtime layer (no DB) + database leaf images.

---

## Per-Layer Requirements

### Tier 0 — `ubi10-core` (NEW)

| Attribute | Value |
|-----------|-------|
| FROM | `registry.access.redhat.com/ubi10/ubi-init:latest` |
| RHSM | No |
| Packages | `iputils`, `bind-utils`, `net-tools`, `less`, `cronie`, `procps-ng`, `diffutils` |
| Services enabled | (none) |
| Services masked | `systemd-remount-fs`, `systemd-update-done`, `systemd-udev-trigger` |
| STOPSIGNAL | `SIGRTMIN+3` |
| ENTRYPOINT | `["/sbin/init"]` |
| Provides downstream | Troubleshooting tools, cron, systemd hardening, init entrypoint |

### Tier 1 — `ubi10-httpd` (NEW)

| Attribute | Value |
|-----------|-------|
| FROM | `quay.io/crunchtools/ubi10-core` |
| RHSM | No |
| Packages | `httpd` |
| Services enabled | `httpd` |
| Inherits | Everything from ubi10-core |
| Provides downstream | Apache web server ready to serve content |

### Tier 2a — `ubi10-httpd-php` (MODIFIED)

| Attribute | Value |
|-----------|-------|
| FROM | `quay.io/crunchtools/ubi10-httpd` |
| RHSM | No |
| Packages | `php`, `php-mysqlnd`, `php-xml`, `php-mbstring`, `php-intl`, `php-gd`, `php-opcache`, `php-pecl-apcu` |
| Services enabled | `php-fpm` |
| Inherits | httpd (enabled), troubleshooting tools, systemd hardening |
| Does NOT include | Any database server — mariadb-server, postgresql-server |

### Tier 2b — `ubi10-httpd-perl` (MODIFIED)

| Attribute | Value |
|-----------|-------|
| FROM | `quay.io/crunchtools/ubi10-httpd` |
| RHSM | No |
| Packages | `mod_fcgid`, `perl` |
| Services enabled | (none additional — httpd inherited) |
| Inherits | httpd (enabled), troubleshooting tools, systemd hardening |
| Does NOT include | Any database server |

### Tier 2c — `proxy` (MODIFIED)

| Attribute | Value |
|-----------|-------|
| FROM | `quay.io/crunchtools/ubi10-httpd` |
| RHSM | No |
| Packages | `mod_ssl` |
| Config | Remove `/etc/httpd/conf.d/ssl.conf` (bind-mounted at runtime) |
| EXPOSE | 80, 443 |
| Inherits | httpd (enabled), troubleshooting tools, systemd hardening |

### Tier 3a — `ubi10-httpd-php-mariadb` (NEW)

| Attribute | Value |
|-----------|-------|
| FROM | `quay.io/crunchtools/ubi10-httpd-php` |
| RHSM | Yes |
| Packages | `mariadb-server`, `mariadb` |
| Services enabled | `mariadb` |
| Inherits | httpd, php-fpm, all PHP extensions, troubleshooting tools |

### Tier 3b — `ubi10-httpd-php-postgres` (NEW)

| Attribute | Value |
|-----------|-------|
| FROM | `quay.io/crunchtools/ubi10-httpd-php` |
| RHSM | Yes |
| Packages | `postgresql-server`, `php-pgsql` |
| Services enabled | `postgresql` |
| Init scripts | `postgres-prep.sh` (initdb if PGDATA empty), `postgres-prep.service` (oneshot, Before=postgresql) |
| Inherits | httpd, php-fpm, all PHP extensions, troubleshooting tools |

### Tier 3c — `ubi10-httpd-perl-mariadb` (NEW)

| Attribute | Value |
|-----------|-------|
| FROM | `quay.io/crunchtools/ubi10-httpd-perl` |
| RHSM | Yes |
| Packages | `mariadb-server`, `mariadb` |
| Services enabled | `mariadb` |
| Inherits | httpd, mod_fcgid, perl, troubleshooting tools |

---

## Containerfile Changes

### Packages removed from `ubi10-httpd-php`

| Package | Reason |
|---------|--------|
| `mariadb-server` | Moved to `ubi10-httpd-php-mariadb` leaf image |
| `mariadb` | Moved to `ubi10-httpd-php-mariadb` leaf image |
| `httpd` | Inherited from `ubi10-httpd` |
| `cronie` | Inherited from `ubi10-core` |
| `procps-ng` | Inherited from `ubi10-core` |
| `diffutils` | Inherited from `ubi10-core` |
| `iputils` | Inherited from `ubi10-core` |
| `bind-utils` | Inherited from `ubi10-core` |
| `net-tools` | Inherited from `ubi10-core` |
| `less` | Inherited from `ubi10-core` |

### RHSM removed from `ubi10-httpd-php`

After MariaDB removal, all remaining packages (`php`, `php-mysqlnd`, `php-xml`, `php-mbstring`, `php-intl`, `php-gd`, `php-opcache`, `php-pecl-apcu`) are available in UBI repos. The `--mount=type=secret` RHSM registration block is removed entirely from this image.

---

## Cascade Rebuild Mechanism

When a parent image changes, all children must rebuild. Two mechanisms work together.

### 1. `repository_dispatch` for immediate cascade on push

Each repo's push job fires `repository_dispatch` events to its direct children. Example for ubi10-core:

```yaml
# In ubi10-core's push job, after successful push:
- name: Trigger downstream rebuilds
  env:
    GH_TOKEN: ${{ secrets.CRUNCHTOOLS_DISPATCH_TOKEN }}
  run: |
    gh api repos/crunchtools/ubi10-httpd/dispatches \
      -f event_type=parent-image-updated
```

Each child workflow listens for `repository_dispatch`:

```yaml
on:
  push:
    branches: [main, master]
  repository_dispatch:
    types: [parent-image-updated]
  workflow_dispatch:
  schedule:
    - cron: '0 6 * * 1'
```

**Cascade chain:**

```
ubi10-core push ──► triggers ubi10-httpd
ubi10-httpd push ──► triggers ubi10-httpd-php, ubi10-httpd-perl, proxy
ubi10-httpd-php push ──► triggers ubi10-httpd-php-mariadb, ubi10-httpd-php-postgres
ubi10-httpd-perl push ──► triggers ubi10-httpd-perl-mariadb
ubi10-httpd-php-mariadb push ──► (no children — leaf image)
ubi10-httpd-php-postgres push ──► triggers zabbix
ubi10-httpd-perl-mariadb push ──► triggers rt
```

Full cascade example: `ubi10-core` changes → core pushes → triggers httpd → httpd pushes → triggers httpd-php, httpd-perl, proxy → httpd-php pushes → triggers mariadb, postgres → postgres pushes → triggers zabbix.

### 2. Weekly cron as safety net

If `repository_dispatch` fails (token expired, API error), staggered weekly cron ensures everything rebuilds within the same day:

| Image | Cron | Tier |
|-------|------|------|
| ubi10-core | Mon 4:00 AM UTC | 0 |
| ubi10-httpd | Mon 4:15 AM UTC | 1 |
| ubi10-httpd-php, ubi10-httpd-perl, proxy | Mon 4:30 AM UTC | 2 |
| ubi10-httpd-php-mariadb, ubi10-httpd-php-postgres, ubi10-httpd-perl-mariadb | Mon 4:45 AM UTC | 3 |
| zabbix, rt | Mon 5:00 AM UTC | 4 |

### Required secret: `CRUNCHTOOLS_DISPATCH_TOKEN`

A fine-grained GitHub PAT scoped to the `crunchtools` org with Contents read/write permission. One token covers the entire org.

**How to create:**

1. Go to GitHub Settings → Developer settings → Fine-grained tokens
2. Name: `crunchtools-dispatch`
3. Resource owner: `crunchtools`
4. Repository access: All repositories (under crunchtools org)
5. Permissions: Contents (Read and write), Metadata (Read-only, auto-granted)
6. Generate and store as org-level secret:

```bash
gh secret set CRUNCHTOOLS_DISPATCH_TOKEN --org crunchtools --body "<token>"
```

Or per-repo if org secrets are unavailable:

```bash
for repo in ubi10-core ubi10-httpd ubi10-httpd-php ubi10-httpd-perl proxy \
            ubi10-httpd-php-mariadb ubi10-httpd-php-postgres ubi10-httpd-perl-mariadb; do
  gh secret set CRUNCHTOOLS_DISPATCH_TOKEN -R crunchtools/$repo --body "<token>"
done
```

---

## Testing Per Layer

| Layer | Tests |
|-------|-------|
| ubi10-core | Package integrity (7 pkgs), systemd boots, 3 services masked, tool binaries exist (`ping`, `dig`, `netstat`, `less`, `crontab`) |
| ubi10-httpd | httpd active, `php -r "file_get_contents('http://localhost/')"` returns default page, httpd package present |
| ubi10-httpd-php | php-fpm active, phpinfo via Apache, PHP modules (mysqlnd, mbstring, xml, intl, gd), `mariadb-server` NOT installed |
| ubi10-httpd-php-mariadb | mariadb active, CREATE DATABASE, CREATE TABLE, INSERT, SELECT, DROP DATABASE |
| ubi10-httpd-php-postgres | postgresql active, PGDATA initialized, createdb, CREATE TABLE, INSERT, SELECT, dropdb |
| ubi10-httpd-perl | mod_fcgid loaded (`httpd -M`), `perl --version`, `mariadb-server` NOT installed |
| ubi10-httpd-perl-mariadb | mariadb active, CREATE DATABASE, CREATE TABLE, INSERT, SELECT, DROP DATABASE |
| proxy | httpd active, mod_ssl loaded (`httpd -M`), ports 80/443 exposed |

Each layer's test script inherits parent assertions. The `ubi10-httpd-php` test explicitly asserts `rpm -q mariadb-server` returns non-zero — this is a regression guard ensuring databases stay in leaf images.

---

## Downstream Consumers

| Consumer | Current FROM | New FROM |
|----------|-------------|----------|
| zabbix | ubi10-httpd-php | ubi10-httpd-php-postgres |
| rt | ubi10-httpd-perl | ubi10-httpd-perl-mariadb |
| WordPress/MediaWiki on lotor (5 sites) | ubi10-httpd-php (image ref) | ubi10-httpd-php-mariadb |
| spanish.crunchtools.com | ubi10-httpd-php | ubi10-httpd-php (static, no DB) |

---

## Implementation Order (Safe Migration)

The migration must not break running WordPress or RT sites. The strategy: build database leaf images first (temporarily redundant with current monolith), migrate consumers to leaf images, then rebase the runtime images to remove databases.

1. Create `ubi10-core` — new repo, Containerfile, CI, tests
2. Create `ubi10-httpd` — new repo, FROM ubi10-core, CI, tests
3. Create `ubi10-httpd-php-mariadb` — FROM current httpd-php (still has MariaDB, temporarily redundant)
4. Create `ubi10-httpd-perl-mariadb` — FROM current httpd-perl (still has MariaDB, same pattern)
5. Migrate lotor: 5 WordPress/MediaWiki sites → `ubi10-httpd-php-mariadb`
6. Update `rt` → FROM `ubi10-httpd-perl-mariadb`
7. Rebase `ubi10-httpd-php` onto `ubi10-httpd` — removes MariaDB + httpd (safe: downstream migrated)
8. Rebase `ubi10-httpd-perl` onto `ubi10-httpd` — removes MariaDB + httpd (safe: rt migrated)
9. Rebuild `ubi10-httpd-php-mariadb` and `ubi10-httpd-perl-mariadb` — now cleanly layer DB on slimmer bases
10. Create `ubi10-httpd-php-postgres` — new repo, FROM ubi10-httpd-php, CI, tests
11. Rebase `proxy` onto `ubi10-httpd`
12. Rebase `zabbix` onto `ubi10-httpd-php-postgres`
13. Wire up `repository_dispatch` cascade across all repos
14. Update factory watchdog — add 5 new repos + 25 Zabbix trapper items

---

## Factory Watchdog

Add 5 new repos to monitoring: `ubi10-core`, `ubi10-httpd`, `ubi10-httpd-php-mariadb`, `ubi10-httpd-php-postgres`, `ubi10-httpd-perl-mariadb`. Creates 25 new Zabbix trapper items (5 dimensions x 5 repos).

---

## CI Pipeline Changes

### Current Pipeline (per image)

```
push to main/master
  ├── build ──► test ──► push
  └── validate-constitution
```

### Proposed Pipeline (per image)

```
push to main/master OR repository_dispatch(parent-image-updated)
  ├── build ──► test ──► push ──► trigger-children
  └── validate-constitution
```

The `trigger-children` step fires `repository_dispatch` events to direct child repos. Leaf images skip this step.

---

## File Changes

### New Repos

| Repo | Purpose |
|------|---------|
| `crunchtools/ubi10-core` | Tier 0 — troubleshooting + systemd hardening base |
| `crunchtools/ubi10-httpd` | Tier 1 — Apache httpd layer |
| `crunchtools/ubi10-httpd-php-mariadb` | Tier 3a — PHP + MariaDB leaf |
| `crunchtools/ubi10-httpd-php-postgres` | Tier 3b — PHP + PostgreSQL leaf |
| `crunchtools/ubi10-httpd-perl-mariadb` | Tier 3c — Perl + MariaDB leaf |

### Modified Repos

| Repo | Changes |
|------|---------|
| `crunchtools/ubi10-httpd-php` | Rebase FROM ubi10-httpd, remove MariaDB + httpd + RHSM, add `repository_dispatch` trigger and listener |
| `crunchtools/ubi10-httpd-perl` | Rebase FROM ubi10-httpd, remove MariaDB + httpd + RHSM, add `repository_dispatch` trigger and listener |
| `crunchtools/proxy` | Rebase FROM ubi10-httpd, add `repository_dispatch` listener |
| `crunchtools/zabbix` | Rebase FROM ubi10-httpd-php-postgres, add `repository_dispatch` listener |
| `crunchtools/rt` | Update FROM to ubi10-httpd-perl-mariadb, add `repository_dispatch` listener |
| `crunchtools/factory` | Add 5 repos to watchdog, 25 new Zabbix trapper items |

---

## Constitution Impact

- [x] Constitution update required

### Constitution v1.2.0 Changes

**Base Image section:**
- Change from `registry.access.redhat.com/ubi10/ubi-init:latest` to `quay.io/crunchtools/ubi10-httpd`

**RHSM Registration section:**
- Remove entirely — ubi10-httpd-php no longer needs RHSM (all packages available in UBI repos)

**Packages Installed section:**
- Remove: `httpd`, `mariadb-server`, `mariadb`, `cronie`, `procps-ng`, `diffutils`, `iputils`, `bind-utils`, `net-tools`, `less`
- Keep: `php`, `php-mysqlnd`, `php-xml`, `php-mbstring`, `php-intl`, `php-gd`, `php-opcache`, `php-pecl-apcu`
- Add note: "Inherited from ubi10-httpd: httpd. Inherited from ubi10-core: iputils, bind-utils, net-tools, less, cronie, procps-ng, diffutils"

**Containerfile Conventions section:**
- Remove: `subscription-manager unregister after package installation`
- Update systemd services enabled: remove `mariadb`
- Add: `repository_dispatch` trigger to child repos

**Testing section:**
- Add: `mariadb-server NOT installed` regression guard
- Update service health tests: remove mariadb

---

## Dependencies

- Depends on: [001-smoke-tests](../001-smoke-tests/spec.md) (test infrastructure)
- Blocks: None

---

## Open Questions

None — all items from issue #2 are covered:
- Core base image with troubleshooting tools (**ubi10-core**)
- ubi10-httpd-php built on base (**via ubi10-httpd**)
- Postgres and MariaDB as separate leaf images (**ubi10-httpd-php-mariadb, ubi10-httpd-php-postgres**)
- Per-layer tests (**testing matrix defined**)
- Database tests (**CREATE/INSERT/SELECT/DROP for both MariaDB and PostgreSQL**)

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2026-03-10 | Initial draft |
