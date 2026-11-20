; ACL2(r) tests of R2A-EXPORT.  Source proof steps are executed, unsafe
; exports are rejected, and R2A-IMPORT's reading of each source book yields
; exactly the interface that ACL2(r) checked and recorded.
; cert_param: (uses-acl2r)
(in-package "ACL2")
(include-book "transfer")
(include-book "std/testing/must-fail" :dir :system)
(include-book "basel-export")
(include-book "example-export")

; The importer's view of BOOK must equal the export recorded by ACL2(r).
(defmacro assert-import-matches-export (book)
  `(make-event
    (er-let* ((export (r2a-source-export ,book state)))
      (if (equal (r2a-strip-proofs (cdr export))
                 (cdr (assoc-eq (car export)
                                (table-alist 'r2a-exports (w state)))))
          (value '(value-triple :ok))
        (er soft 'assert-import-matches-export
            "R2A-IMPORT would not read the interface recorded for ~x0."
            ,book)))))

(assert-import-matches-export "basel-export")
(assert-import-matches-export "example-export")

(assert-event
 (equal (cdr (assoc-eq 'basel (table-alist 'r2a-exports (w state))))
        '((include-book "rational-defs")
          (defthm bq-fixed-odd-enclosure-export (bq-fixed-odd-enclosure n)
            :rule-classes nil))))

(r2a-export analytic-locals-are-allowed
  (local (include-book "nonstd/nsa/sqrt" :dir :system))
  (local (defun local-root () (acl2-sqrt 2)))
  (local
   (defthm local-root-squared
     (equal (* (local-root) (local-root)) 2)
     :hints (("Goal" :use ((:instance sqrt-sqrt (x 2)))
              :in-theory (disable acl2-sqrt)))))
  (defun rational-two () 2)
  (defthm rational-two-positive (< 0 (rational-two))))

(assert-event
 (equal (cdr (assoc-eq 'analytic-locals-are-allowed
                      (table-alist 'r2a-exports (w state))))
        '((defun rational-two () 2)
          (defthm rational-two-positive (< 0 (rational-two))
            :rule-classes nil))))

; The exported theorem itself must be proved.
(must-fail (r2a-export reject-false (defthm source-false nil :rule-classes nil)))

; Projection does not excuse a false local proof in the source development.
(must-fail
 (r2a-export reject-false-local
   (local (defthm false-local nil :rule-classes nil))
   (defthm retained-true (equal 1 1))))

; Matt's example: a witness inside a retained nontrivial encapsulate must be
; checked, even though the exported formula looks portable.
(must-fail
 (r2a-export reject-matt-witness
   (encapsulate ((my-sqrt-2 () t))
     (local (defun my-sqrt-2 () (acl2-sqrt 2)))
     (defthm bad (equal (* (my-sqrt-2) (my-sqrt-2)) 2)))))

; The stronger DEFCHOOSE counterexample also remains rejected.
(must-fail
 (r2a-export reject-real-choice
   (defchoose chosen-root (x) () (equal (* x x) 2))
   (defthm bad (equal (* (chosen-root) (chosen-root)) 2))))

; A theorem may not mention a dropped LOCAL definition.
(must-fail
 (r2a-export reject-local-leak
   (local (defun temporary-id (x) x))
   (defthm illegal-leak (equal (temporary-id x) x))))

; The post-proof check must notice a skipped proof even inside a local event.
(must-fail
 (r2a-export reject-skipped-local
   (local (skip-proofs (defthm skipped-true (equal 1 1) :rule-classes nil)))
   (defthm retained-true (equal 1 1) :rule-classes nil)))

; A retained include-book must name a portable sibling book.
(must-fail
 (r2a-export reject-system-include
   (include-book "nonstd/nsa/sqrt" :dir :system)
   (defthm retained-true (equal 1 1))))
(must-fail
 (r2a-export reject-nonportable-book
   (include-book
    "basel-analytic")
   (defthm retained-true (equal 1 1))))
