# Specification: Smoke Tests, Service Tests, and Troubleshooting Packages

> **Spec ID:** 001-smoke-tests
> **Status:** Implemented
> **Version:** 0.1.0
> **Author:** Scott McCarty
> **Date:** 2026-03-10
> **Closes:** [#1](https://github.com/crunchtools/ubi10-httpd-php/issues/1)

## Overview

Add smoke tests, service tests, and package integrity checks to the CI pipeline. Add troubleshooting packages to the image so running containers are easier to debug. Restructure CI from a single build+push job into a build/test/push pipeline so broken images never reach the registry.

---

## Containerfile Changes

| Change | Description |
|--------|-------------|
| Package additions | Add `iputils`, `bind-utils`, `net-tools`, `less` for troubleshooting |
| RHSM registration | Migrate from `ARG`-based registration to `--mount=type=secret` (constitution violation fix) |

### RHSM Constitution Violation Fix

The current Containerfile uses `ARG RHSM_ACTIVATION_KEY` / `ARG RHSM_ORG_ID` and passes credentials as build-args. The Container Image profile (Section II — Containerfile Conventions) requires `--mount=type=secret` for credential handling. This spec bundles the fix.

**Current (non-compliant):**
```dockerfile
ARG RHSM_ACTIVATION_KEY
ARG RHSM_ORG_ID
RUN subscription-manager register --activationkey="$RHSM_ACTIVATION_KEY" --org="$RHSM_ORG_ID"
```

**Proposed (compliant):**
```dockerfile
RUN --mount=type=secret,id=RHSM_ACTIVATION_KEY \
    --mount=type=secret,id=RHSM_ORG_ID \
    subscription-manager register \
      --activationkey="$(cat /run/secrets/RHSM_ACTIVATION_KEY)" \
      --org="$(cat /run/secrets/RHSM_ORG_ID)" \
    && dnf install -y \
      httpd mariadb-server mariadb \
      php php-mysqlnd php-json php-xml php-mbstring php-intl php-gd php-opcache php-pecl-apcu \
      cronie procps-ng diffutils \
      iputils bind-utils net-tools less \
    && dnf clean all \
    && subscription-manager unregister
```

This consolidates register/install/unregister into a single `RUN` layer so secrets are never cached in intermediate layers.

---

## Package Changes

### New Packages

| Package | Purpose |
|---------|---------|
| `iputils` | `ping` — network reachability testing |
| `bind-utils` | `dig`, `nslookup` — DNS troubleshooting |
| `net-tools` | `netstat` — connection and socket inspection |
| `less` | Pager for log file inspection |

---

## Testing Requirements

### Service Health Tests

| Service | Check Command | Pass Criteria |
|---------|--------------|---------------|
| httpd | `systemctl is-active httpd` | exit 0 |
| mariadb | `systemctl is-active mariadb` | exit 0 |

### Functional Tests

| Test | Command | Pass Criteria |
|------|---------|---------------|
| PHP via Apache | `curl -sf http://localhost/test.php` | Response contains `PHP Version` |
| PHP modules loaded | `php -m` | Contains: `mysqlnd`, `mbstring`, `xml`, `intl`, `gd` |

### Package Integrity Tests

All packages verified present via `rpm -q`:

`httpd`, `mariadb-server`, `mariadb`, `php`, `php-mysqlnd`, `php-json`, `php-xml`, `php-mbstring`, `php-intl`, `php-gd`, `php-opcache`, `php-pecl-apcu`, `cronie`, `procps-ng`, `diffutils`, `iputils`, `bind-utils`, `net-tools`, `less`

### Test Script

`tests/smoke-test.sh` — single executable script that runs all tests inside the container. Exit codes:
- `0` — all tests pass
- `1` — one or more tests failed (with summary of failures)

The script creates a temporary `/var/www/html/test.php` containing `<?php phpinfo(); ?>` for the PHP functional test, then removes it after the test completes.

---

## CI Pipeline Changes

### Current Pipeline

```
push to main/master
  ├── build (build + push in one job)
  └── validate-constitution (parallel)
```

### Proposed Pipeline

```
push to main/master
  ├── build ──► test ──► push
  └── validate-constitution (parallel)
```

**Job details:**

| Job | Depends On | What It Does |
|-----|-----------|--------------|
| `build` | — | Build image, export as OCI tarball artifact |
| `test` | `build` | Load image, start container with `--systemd=always`, run `tests/smoke-test.sh` inside it |
| `push` | `test` | Push to `quay.io/crunchtools/ubi10-httpd-php` |
| `validate-constitution` | — | Validate `.specify/memory/constitution.md` (unchanged, runs in parallel) |

The `test` job needs to:
1. Load the OCI image from the build artifact
2. Start the container with `podman run -d --systemd=always`
3. Wait for systemd to bring up services (~5-10 seconds)
4. Copy `tests/smoke-test.sh` into the container and execute it
5. Capture exit code and logs

---

## File Changes

### New Files

| File | Purpose |
|------|---------|
| `.specify/specs/001-smoke-tests/spec.md` | This spec |
| `.specify/templates/spec-template.md` | Container image spec template |
| `tests/smoke-test.sh` | Smoke test script (all tests) |

### Modified Files

| File | Changes |
|------|---------|
| `Containerfile` | Add debug packages, fix RHSM to `--mount=type=secret`, consolidate RUN layers |
| `.github/workflows/build.yml` | Restructure into build → test → push jobs |
| `.specify/memory/constitution.md` | Update Testing + Quality Gates sections, bump to v1.1.0 |

---

## Constitution Impact

- [x] Constitution update required

### Constitution v1.1.0 Changes

**RHSM Registration section:**
- Change from "Uses build-arg based subscription-manager registration" to "Uses `--mount=type=secret` for subscription-manager registration"

**Testing section** — expand from:
```
- Build test: CI builds the image on every push
- Security scan: Recommended (not yet implemented)
```
To:
```
- Build test: CI builds the image on every push
- Smoke tests: Service health, PHP functional, package integrity
- Security scan: Recommended (not yet implemented)
```

**Quality Gates section** — expand from:
```
1. Build — CI builds the Containerfile successfully
2. Weekly rebuild — cron job picks up base image updates
```
To:
```
1. Build — CI builds the Containerfile successfully
2. Test — smoke tests pass (services up, PHP works, packages present)
3. Push — image published only after tests pass
4. Weekly rebuild — cron job picks up base image updates
```

---

## Dependencies

- Depends on: None
- Blocks: None

---

## Open Questions

None — all three items from issue #1 are covered.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2026-03-10 | Initial draft |
