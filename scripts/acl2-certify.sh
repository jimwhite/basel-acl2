#!/usr/bin/env bash
# Ordinary ACL2 target side: certify the client books as documented in
# README.md ("Ordinary ACL2 certification") and evaluate the interval.
#
# Certificate isolation: this works in a fresh copy of the package under
# build/acl2 (only sources and receipts are copied, never .cert files), uses
# the ordinary installation's own system books, and refuses to run ACL2(r).
#
# Usage: scripts/acl2-certify.sh [RECEIPT]
#   RECEIPT defaults to the distributed basel.r2a. Pass
#   build/acl2r/new-basel.r2a to import a receipt you regenerated.
# Env:   ACL2_ROOT (default /opt/acl2), ACL2 (default $ACL2_ROOT/saved_acl2),
#        BUILD_DIR (default <repo>/build/acl2), JOBS (default 2)
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
receipt_path=${1:-$repo/basel.r2a}
if [ ! -f "$receipt_path" ]; then
  echo "Receipt not found: $receipt_path" >&2
  if [ "$#" -gt 0 ]; then
    echo "Run scripts/acl2r-reproduce.sh first to generate a receipt, or omit the argument to use basel.r2a." >&2
  fi
  exit 2
fi
receipt=$(realpath "$receipt_path")
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
mkdir -p "$build/logs"
cp "$repo"/*.lisp "$repo"/*.lsp "$repo"/*.acl2 "$repo"/example.r2a "$build"/
cp "$receipt" "$build/basel.r2a"
cd "$build"

fail=0
check() {
  if "${@:2}"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi
}
# Result line printed by ACL2 (not the echoed input form, which also contains it).
marker() { grep -qxE "(ACL2(\\(r\\))? !>+)?[[:space:]]*$1[[:space:]]*" "$2"; }

echo "== cert.pl (receipt: $receipt)"
if "$ACL2_ROOT/books/build/cert.pl" --acl2 "$ACL2" -j "${JOBS:-2}" \
     transfer-tests.lisp development-tests.lisp example-import.lisp \
     demo.lisp basel-interval.lisp > logs/cert.log 2>&1; then
  echo "PASS: cert.pl"
else
  echo "FAIL: cert.pl (see $build/logs/cert.log)"; tail -40 logs/cert.log; fail=1
fi
for b in transfer transfer-tests development-tests example-import rational-defs \
         rational-proofs trusted-bridge basel-rational demo basel-interval; do
  check "$b.cert written" test -f "$b.cert"
done

echo "== books that must not use trust tags"
"$ACL2" > logs/no-ttags.log 2>&1 <<'EOF' || true
(progn (include-book "transfer" :ttags nil :uncertified-okp nil)
       (include-book "rational-proofs" :ttags nil :uncertified-okp nil)
       (value-triple :no-ttags-check-passed))
(good-bye)
EOF
check "transfer, rational-proofs include with :ttags nil" \
  marker ':NO-TTAGS-CHECK-PASSED' logs/no-ttags.log

echo "== interval evaluation"
"$ACL2" > logs/interval.log 2>&1 <<'EOF' || true
(include-book "basel-interval" :ttags (:acl2r-checked-transfer)
              :uncertified-okp nil)
(bq-basel-interval 100000000000000000000)
(progn
 (assert-event
  (let ((iv (bq-basel-interval 100000000000000000000)))
    (equal (- (cdr iv) (car iv))
           809439510239319549231/20000000000000000000000000000000000000000)))
 (value-triple :interval-check-passed))
(good-bye)
EOF
check "bq-basel-interval width at 10^20" marker ':INTERVAL-CHECK-PASSED' logs/interval.log

echo "Logs: $build/logs"
exit $fail
