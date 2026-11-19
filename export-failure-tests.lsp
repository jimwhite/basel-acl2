; Fresh ACL2(r), after certifying transfer. Errors from the three LD calls
; are EXPECTED. Each following assertion checks that no export was recorded.
(in-package "ACL2")
(include-book "transfer")

(ld '((r2a-export reject-matt
        (encapsulate ((my-sqrt-2 () t))
          (local (defun my-sqrt-2 () (acl2-sqrt 2)))
          (defthm bad (equal (* (my-sqrt-2) (my-sqrt-2)) 2)))))
    :ld-error-action :return)
(assert-event
 (not (assoc-eq 'reject-matt (table-alist 'r2a-exports (w state)))))

(ld '((r2a-export reject-false (defthm source-false nil)))
    :ld-error-action :return)
(assert-event
 (not (assoc-eq 'reject-false (table-alist 'r2a-exports (w state)))))

; First-pass success is insufficient: the final theorem leaks a local name.
(ld '((r2a-export reject-local-leak
        (local (defun temporary-id (x) x))
        (defthm illegal-leak (equal (temporary-id x) x))))
    :ld-error-action :return)
(assert-event
 (not (assoc-eq 'reject-local-leak (table-alist 'r2a-exports (w state)))))
(value-triple :all-expected-export-failures-checked)
