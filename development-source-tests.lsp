; Run in a fresh ACL2(r) after certifying transfer. Expected errors below
; verify that source proof steps are executed, and unsafe exports rejected.
(in-package "ACL2")
(include-book "transfer")

(r2a-export-development analytic-locals-are-allowed
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

; Projection does not excuse a false local proof in the source development.
(ld '((r2a-export-development reject-false-local
        (local (defthm false-local nil))
        (defthm retained-true (equal 1 1))))
    :ld-error-action :return)
(assert-event
 (not (assoc-eq 'reject-false-local (table-alist 'r2a-exports (w state)))))

; A witness inside a retained nontrivial encapsulate must be checked.
(ld '((r2a-export-development reject-matt-witness
        (local (include-book "nonstd/nsa/sqrt" :dir :system))
        (encapsulate ((my-sqrt-2 () t))
          (local (defun my-sqrt-2 () (acl2-sqrt 2)))
          (defthm bad (equal (* (my-sqrt-2) (my-sqrt-2)) 2)))))
    :ld-error-action :return)
(assert-event
 (not (assoc-eq 'reject-matt-witness (table-alist 'r2a-exports (w state)))))

; The stronger DEFCHOOSE counterexample also remains rejected.
(ld '((r2a-export-development reject-real-choice
        (local (include-book "nonstd/nsa/sqrt" :dir :system))
        (defchoose chosen-root (x) () (equal (* x x) 2))
        (defthm bad (equal (* (chosen-root) (chosen-root)) 2))))
    :ld-error-action :return)
(assert-event
 (not (assoc-eq 'reject-real-choice (table-alist 'r2a-exports (w state)))))

; The post-proof check must notice a skipped proof even inside a local event.
(ld '((r2a-export-development reject-skipped-local
        (local (skip-proofs (defthm skipped-true (equal 1 1) :rule-classes nil)))
        (defthm retained-true (equal 1 1) :rule-classes nil)))
    :ld-error-action :return)
(assert-event
 (not (assoc-eq 'reject-skipped-local (table-alist 'r2a-exports (w state)))))
(value-triple :development-source-tests-passed)
