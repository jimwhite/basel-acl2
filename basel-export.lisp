(in-package "ACL2")
(include-book "transfer")

; ACL2(r) source of the Basel transfer.  Certifying this book in ACL2(r)
; proves the export; basel-import.lisp reads this same file in ACL2.
; Keep the book to exactly these three forms, which R2A-IMPORT requires.
; The LOCAL analytic book is omitted from the interface; the definitions in
; rational-defs are checked and then included natively by ordinary ACL2.
; cert_param: (uses-acl2r)
; SPDX-License-Identifier: MIT
(r2a-export basel
  (include-book "rational-defs")
  (local (include-book "basel-analytic"))
  (defthm bq-fixed-odd-enclosure-export
    (bq-fixed-odd-enclosure n)
    :hints (("Goal" :by bq-analytic-odd-enclosure))))
