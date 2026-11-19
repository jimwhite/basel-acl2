(in-package "ACL2")
; (depends-on "example.r2a")
(include-book "transfer")
(r2a-import "example.r2a")
(defthm use-imported-half
  (acl2-numberp (portable-half x))
  :hints (("Goal" :use half-rational)))
