#!/usr/bin/env bash
# Ordinary ACL2 side: import the ACL2(r) exports and certify the clients and
# tests.  All checking happens in the books themselves; this script only
# isolates the certificates (ACL2 and ACL2(r) both write .cert files for the
# shared books) by certifying a fresh copy of the sources under build/acl2.
#
# Usage: scripts/acl2-certify.sh
# Env:   ACL2_ROOT (default /opt/acl2), ACL2 (default $ACL2_ROOT/saved_acl2),
#        BUILD_DIR (default <repo>/build/acl2), JOBS (default 2)
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
ACL2_ROOT=${ACL2_ROOT:-/opt/acl2}
ACL2=${ACL2:-$ACL2_ROOT/saved_acl2}
build=${BUILD_DIR:-$repo/build/acl2}
# Use the system books that belong to this executable, not an override.
unset ACL2_SYSTEM_BOOKS

[ -x "$ACL2" ] || { echo "ACL2 executable not found: $ACL2" >&2; exit 2; }
banner=$(echo '(good-bye)' | "$ACL2" 2>&1)
if ! grep -q 'ACL2 !>' <<<"$banner" || grep -q 'ACL2(r) !>' <<<"$banner"; then
  echo "$ACL2 is not ordinary ACL2; refusing to mix certificates" >&2; exit 2
fi

rm -rf "$build"
mkdir -p "$build"
cp -r "$repo"/*.lisp "$repo"/*.acl2 "$repo"/import-fixtures "$build"/
cd "$build"

targets=(basel-interval demo example-import import-tests transfer-tests)
if "$ACL2_ROOT/books/build/cert.pl" --acl2 "$ACL2" -j "${JOBS:-2}" \
     "${targets[@]}" > cert.log 2>&1; then
  echo "PASS: ACL2 certified ${targets[*]} (log: $build/cert.log)"
else
  echo "FAIL: see $build/cert.log" >&2; tail -40 cert.log >&2; exit 1
fi
