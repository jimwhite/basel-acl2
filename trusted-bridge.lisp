; General checked event transfer, specialized by an ACL2(r) receipt.
; SPDX-License-Identifier: MIT
(in-package "ACL2")
; (depends-on "basel.r2a")
(include-book "rational-defs")
(include-book "transfer")

; The receipt contains the complete portable interface. The generic
; importer checks every event, including LOCAL witnesses, and admits all
; definitions normally. It does not include an ACL2(r) certificate in ACL2.
(r2a-import "basel.r2a")

(defthm bq-imported-odd-enclosure
  (bq-fixed-odd-enclosure n)
  :hints (("Goal" :by bq-fixed-odd-enclosure-export))
  :rule-classes nil)
