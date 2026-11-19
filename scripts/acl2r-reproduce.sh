#!/usr/bin/env bash
# ACL2(r) source side: reproduce the Basel proof and receipt as documented in
# README.md ("Reproduce the ACL2(r) proof and receipt"), plus the example
# export and the expected-error regressions.
#
# Works in a fresh copy of the package under build/acl2r so that ACL2(r)
# certificates never mix with ordinary ACL2 certificates.
#
# Usage: scripts/acl2r-reproduce.sh
# Env:   ACL2_ROOT (default /opt/acl2), ACL2R (default $ACL2_ROOT/saved_acl2r),
#        BUILD_DIR (default <repo>/build/acl2r)
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
ACL2_ROOT=${ACL2_ROOT:-/opt/acl2}
ACL2R=${ACL2R:-$ACL2_ROOT/saved_acl2r}
build=${BUILD_DIR:-$repo/build/acl2r}
basel=$ACL2_ROOT/books/nonstd/basel

[ -x "$ACL2R" ] || { echo "ACL2(r) executable not found: $ACL2R" >&2; exit 2; }
[ -f "$basel/basel-series.lisp" ] || {
  echo "Missing $basel/basel-series.lisp (see README: acl2r-context branch)" >&2
  exit 2
}

rm -rf "$build"
mkdir -p "$build/logs" "$build/reference"
cp "$repo"/*.lisp "$repo"/*.lsp "$repo"/*.acl2 "$build"/
cp "$repo"/basel.r2a "$repo"/example.r2a "$build"/reference/
cd "$build"

fail=0
run() {  # run NAME: feed stdin to a fresh ACL2(r) session, log to logs/NAME.log
  local name=$1
  echo "== ACL2(r) session: $name"
  "$ACL2R" > "logs/$name.log" 2>&1 || true
}
check() {  # check DESCRIPTION COMMAND...
  if "${@:2}"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi
}
no_errors() { ! grep -qE 'ACL2 Error|\*\* FAILED \*\*|Raw Lisp Break|debugger invoked' "$1"; }

# 1. The main sequence, exactly as in README.md.
run basel <<EOF
(certify-book "transfer" 0)
(u)
(certify-book "transfer-tests" 0)
(u)
(certify-book "development-tests" 0)
(u)
(certify-book "prepare-basel" 0)
(u)
(certify-book "$basel/complex-helper" 0)
(u)

(include-book "prepare-basel")
(r2a-prepare-basel-development
 "$basel/basel-series.lisp"
 "rational-defs.lisp"
 "acl2r-export-tail.lsp"
 "$basel/complex-helper"
 "basel-analytic"
 "basel-source"
 state)
(ubt 1)

(certify-book "basel-analytic" 0)
(u)
(certify-book "basel-source" 0)
(u)
(include-book "basel-source")
(r2a-write-export 'basel "new-basel.r2a" state)
(good-bye)
EOF
check "main sequence has no errors" no_errors logs/basel.log
for b in transfer transfer-tests development-tests prepare-basel basel-analytic basel-source; do
  check "$b.cert written" test -f "$b.cert"
done
check "new-basel.r2a written" test -f new-basel.r2a
grep -A8 'Form:  (CERTIFY-BOOK "basel-analytic"' logs/basel.log | grep -E 'Time|Prover steps' || true
grep -A8 'Form:  (CERTIFY-BOOK "basel-source"' logs/basel.log | grep -E 'Time|Prover steps' || true

# Receipts start with (:R2A-V1 "<acl2-version>" ...). The version string
# depends on the ACL2 build; the transferred events must not.
body() { sed -E 's/^\(:R2A-V1 "[^"]*"//' "$1"; }
if [ -f new-basel.r2a ]; then
  if cmp -s new-basel.r2a reference/basel.r2a; then
    echo "PASS: new-basel.r2a is byte-for-byte identical to basel.r2a"
  else
    check "new-basel.r2a events identical to basel.r2a (version header differs)" \
      cmp -s <(body new-basel.r2a) <(body reference/basel.r2a)
    echo "     new header: $(grep -oE '^\(:R2A-V1 "[^"]*"' new-basel.r2a)"
  fi
fi

# 2. Small encapsulate example (no preexisting example.r2a).
run example <<'EOF'
(ld "example-export.lsp")
(good-bye)
EOF
check "example export has no errors" no_errors logs/example.log
if [ -f example.r2a ]; then
  check "example.r2a events identical to distributed example.r2a" \
    cmp -s <(body example.r2a) <(body reference/example.r2a)
else
  check "example.r2a written" false
fi

# 3. Expected-error regressions (errors in the logs are expected here).
run development-source-tests <<'EOF'
(ld "development-source-tests.lsp")
(good-bye)
EOF
# A failed top-level form does not stop LD, so also require no failed assertion.
# The marker must be a printed result line, not the echoed input form.
passed() {
  grep -qxE "(ACL2(\\(r\\))? !>+)?[[:space:]]*$1[[:space:]]*" "$2" && ! grep -q 'Assertion failed' "$2"
}
check "development-source-tests passed" \
  passed ':DEVELOPMENT-SOURCE-TESTS-PASSED' logs/development-source-tests.log

run export-failure-tests <<'EOF'
(ld "export-failure-tests.lsp")
(good-bye)
EOF
check "export-failure-tests passed" \
  passed ':ALL-EXPECTED-EXPORT-FAILURES-CHECKED' logs/export-failure-tests.log

echo "Logs: $build/logs"
[ -f "$build/new-basel.r2a" ] && echo "Receipt: $build/new-basel.r2a"
exit $fail
