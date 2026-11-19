; Start a fresh ACL2(r) in this directory (with its own certified transfer).
(in-package "ACL2")
(include-book "transfer")
(r2a-export example
  (defun rational-double (x) (* 2 (ifix x)))
  (defthm double-is-rational (rationalp (rational-double x)))
  (encapsulate ((portable-half (x) t))
    (local (defun portable-half (x) (/ (ifix x) 2)))
    (local (defun portable-helper (x) (portable-half x)))
    (local (defthm helper-rational (rationalp (portable-helper x))))
    (defthm half-rational (rationalp (portable-half x)))))
(r2a-write-export 'example "example.r2a" state)
