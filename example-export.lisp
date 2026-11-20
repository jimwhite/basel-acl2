(in-package "ACL2")
(include-book "transfer")

; A small ACL2(r) export, imported by example-import.lisp.  The constrained
; function's LOCAL witness and helpers are retained and checked.
; cert_param: (uses-acl2r)
(r2a-export example
  (defun rational-double (x) (* 2 (ifix x)))
  (defthm double-is-rational (rationalp (rational-double x)))
  (encapsulate ((portable-half (x) t))
    (local (defun portable-half (x) (/ (ifix x) 2)))
    (local (defun portable-helper (x) (portable-half x)))
    (local (defthm helper-rational (rationalp (portable-helper x))))
    (defthm half-rational (rationalp (portable-half x)))))
