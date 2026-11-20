; R2A-IMPORT fixture: a retained include of the nonportable sibling book.
(in-package "ACL2")
(include-book "transfer")
(r2a-export includes-nonportable
  (include-book
   "nonportable")
  (defthm root-two-number (acl2-numberp (root-two)) :rule-classes nil))
