#!/usr/bin/env bash
# ACL2(r) side: certify the Basel export, the example export, and the tests.
# All checking happens in the books themselves; this script only isolates the
# certificates (ACL2 and ACL2(r) both write .cert files for the shared books)
# by certifying a fresh copy of the sources under build/acl2r.
#
# Usage: scripts/acl2r-certify.sh
# Env:   ACL2R_ROOT (default /opt/acl2r), ACL2R (default $ACL2R_ROOT/saved_acl2r),
#        BUILD_DIR (default <repo>/build/acl2r), JOBS (default 2)
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
ACL2R_ROOT=${ACL2R_ROOT:-/opt/acl2r}
ACL2R=${ACL2R:-$ACL2R_ROOT/saved_acl2r}
build=${BUILD_DIR:-$repo/build/acl2r}
# Use the system books that belong to this executable, not an override.
unset ACL2_SYSTEM_BOOKS

[ -x "$ACL2R" ] || { echo "ACL2(r) executable not found: $ACL2R" >&2; exit 2; }
echo '(good-bye)' | "$ACL2R" 2>&1 | grep -q 'ACL2(r) !>' || {
  echo "$ACL2R is not ACL2(r); refusing to mix certificates" >&2; exit 2
}
[ -f "$ACL2R_ROOT/books/nonstd/basel/basel-series.lisp" ] || {
  echo "Missing nonstd/basel/basel-series.lisp (see README)" >&2; exit 2
}

rm -rf "$build"
mkdir -p "$build"
cp "$repo"/*.lisp "$repo"/*.acl2 "$build"/
cd "$build"

targets=(basel-export example-export export-tests transfer-tests)
if "$ACL2R_ROOT/books/build/cert.pl" --acl2 "$ACL2R" -j "${JOBS:-2}" \
     "${targets[@]}" > cert.log 2>&1; then
  echo "PASS: ACL2(r) certified ${targets[*]} (log: $build/cert.log)"
else
  echo "FAIL: see $build/cert.log" >&2; tail -40 cert.log >&2; exit 1
fi
