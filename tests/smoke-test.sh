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

if systemctl is-active mariadb >/dev/null 2>&1; then
    pass "mariadb is active"
else
    fail "mariadb is not active"
fi

if systemctl is-active php-fpm >/dev/null 2>&1; then
    pass "php-fpm is active"
else
    fail "php-fpm is not active"
fi

# ---------- Functional Tests ----------
echo "=== Functional Tests ==="

# PHP via Apache — create temp phpinfo page, test, clean up
TEST_PHP="/var/www/html/test.php"
echo '<?php phpinfo(); ?>' > "$TEST_PHP"

RESPONSE=""
for i in $(seq 1 10); do
    RESPONSE=$(php -r "echo @file_get_contents('http://localhost/test.php') ?: '';" 2>/dev/null || true)
    if echo "$RESPONSE" | grep -q "PHP Version"; then
        break
    fi
    sleep 1
done
if echo "$RESPONSE" | grep -q "PHP Version"; then
    pass "PHP via Apache returns phpinfo"
else
    fail "PHP via Apache did not return phpinfo"
fi

rm -f "$TEST_PHP"

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

PACKAGES=(
    httpd
    mariadb-server
    mariadb
    php
    php-mysqlnd
    php-xml
    php-mbstring
    php-intl
    php-gd
    php-opcache
    php-pecl-apcu
    cronie
    procps-ng
    diffutils
    iputils
    bind-utils
    net-tools
    less
)

for pkg in "${PACKAGES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        pass "package: $pkg"
    else
        fail "package missing: $pkg"
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
