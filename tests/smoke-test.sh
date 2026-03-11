#!/bin/bash
# smoke-test.sh — smoke tests for ubi10-httpd-php container image
# Run inside a running container started with --systemd=always
# Exit 0 = all pass, Exit 1 = one or more failures

set -uo pipefail

FAILURES=0
TESTS=0

pass() {
    TESTS=$((TESTS + 1))
    echo "  PASS: $1"
}

fail() {
    TESTS=$((TESTS + 1))
    FAILURES=$((FAILURES + 1))
    echo "  FAIL: $1"
}

# ---------- Service Health ----------
echo "=== Service Health ==="

if systemctl is-active httpd >/dev/null 2>&1; then
    pass "httpd is active"
else
    fail "httpd is not active"
fi

if systemctl is-active php-fpm >/dev/null 2>&1; then
    pass "php-fpm is active"
else
    fail "php-fpm is not active"
fi

# ---------- Negative Assertion ----------
echo "=== Negative Assertions ==="

# mariadb-server must NOT be installed — databases belong in leaf images
if rpm -q mariadb-server >/dev/null 2>&1; then
    fail "mariadb-server is installed (should be in leaf images only)"
else
    pass "mariadb-server NOT installed (correct)"
fi

# ---------- Functional Tests ----------
echo "=== Functional Tests ==="

# PHP via Apache — create temp phpinfo page, test, clean up
TEST_PHP="/var/www/html/test.php"
echo '<?php phpinfo(); ?>' > "$TEST_PHP"

RESPONSE_FILE=$(mktemp)
PHP_OK=false
for i in $(seq 1 10); do
    php -r "echo @file_get_contents('http://localhost/test.php') ?: '';" > "$RESPONSE_FILE" 2>/dev/null || true
    if grep -q "phpinfo" "$RESPONSE_FILE"; then
        PHP_OK=true
        break
    fi
    sleep 1
done
if $PHP_OK; then
    pass "PHP via Apache returns phpinfo"
else
    fail "PHP via Apache did not return phpinfo"
fi

rm -f "$TEST_PHP" "$RESPONSE_FILE"

# PHP modules
echo "--- PHP Modules ---"
PHP_MODULES=$(php -m 2>/dev/null)
for mod in mysqlnd mbstring xml intl gd; do
    if echo "$PHP_MODULES" | grep -qi "^${mod}$"; then
        pass "PHP module: $mod"
    else
        fail "PHP module missing: $mod"
    fi
done

# ---------- Package Integrity ----------
echo "=== Package Integrity ==="

PHP_PACKAGES=(php php-mysqlnd php-xml php-mbstring php-intl php-gd php-opcache php-pecl-apcu)
for pkg in "${PHP_PACKAGES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        pass "package: $pkg"
    else
        fail "package missing: $pkg"
    fi
done

# ---------- Inherited (ubi10-httpd + ubi10-core) ----------
echo "=== Inherited ==="

INHERITED_PACKAGES=(httpd iputils bind-utils net-tools less cronie procps-ng diffutils)
for pkg in "${INHERITED_PACKAGES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        pass "inherited package: $pkg"
    else
        fail "inherited package missing: $pkg"
    fi
done

# ---------- Summary ----------
echo ""
echo "=== Results: $((TESTS - FAILURES))/$TESTS passed ==="

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES test(s) failed"
    exit 1
fi

echo "All tests passed"
exit 0
