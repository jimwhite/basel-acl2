; cert_param: (non-acl2r)
(in-package "ACL2")
; (depends-on "example-export.lisp")
(include-book "transfer")
(r2a-import "example-export")
(defthm use-imported-half
  (acl2-numberp (portable-half x))
  :hints (("Goal" :use half-rational)))
