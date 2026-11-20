; R2A-IMPORT fixture: ACL2 and ACL2(r) could read this file differently.
(in-package "ACL2")
(include-book "transfer")
(r2a-export reader-conditional
  (defthm flavor-dependent #+non-standard-analysis t #-non-standard-analysis t
    :rule-classes nil))
