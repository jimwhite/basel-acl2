; Deliberate trust boundary. Read README.md before certifying this book.
; SPDX-License-Identifier: MIT
(in-package "ACL2")
(include-book "rational-defs")

; The only discharged clause is the exact universally quantified theorem
; proved by the ACL2(r) exporter. Other clauses are returned unchanged.
; This is a manually audited import, NOT an ACL2(r) certificate checker.
(defun bq-acl2r-export-cp (clause)
  (if (equal clause '((bq-fixed-odd-enclosure n)))
      nil
    (list clause)))

; The supporters are essential: the imported theorem depends on these
; concrete definitions, not merely on their names.
(define-trusted-clause-processor
  bq-acl2r-export-cp
  (bq-fixed-odd-enclosure bq-odd-enclosurep
   basel-odds bq-pi-lo bq-pi-hi)
  :ttag :basel-acl2r-finite-bounds)

(defthm bq-imported-odd-enclosure
  (bq-fixed-odd-enclosure n)
  :hints (("Goal" :clause-processor (bq-acl2r-export-cp clause)))
  :rule-classes nil)

; Negative checks of the trusted processor's recognition boundary.
(assert-event (equal (bq-acl2r-export-cp nil) (list nil)))
(assert-event
 (equal (bq-acl2r-export-cp '((equal x y))) '(((equal x y)))))
(assert-event
 (equal (bq-acl2r-export-cp '((bq-fixed-odd-enclosure x)))
        '(((bq-fixed-odd-enclosure x)))))
(assert-event
 (equal (bq-acl2r-export-cp '((not (bq-fixed-odd-enclosure n))))
        '(((not (bq-fixed-odd-enclosure n))))))
(assert-event
 (equal (bq-acl2r-export-cp '((bq-fixed-odd-enclosure n) nil))
        '(((bq-fixed-odd-enclosure n) nil))))
