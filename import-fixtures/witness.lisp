; R2A-IMPORT fixture: Matt's example.  The importer re-checks the witness of a
; retained encapsulate and rejects ACL2-SQRT.
(in-package "ACL2")
(include-book "transfer")
(r2a-export witness
  (encapsulate ((my-sqrt-2 () t))
    (local (defun my-sqrt-2 () (acl2-sqrt 2)))
    (defthm my-sqrt-2-squared (equal (* (my-sqrt-2) (my-sqrt-2)) 2))))
