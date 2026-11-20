; R2A-IMPORT fixture: a well-formed export book that ACL2(r) never certified,
; so there is no import-fixtures/uncertified.cert.
(in-package "ACL2")
(include-book "transfer")
(r2a-export uncertified
  (defthm uncertified-fact (equal (+ 1 1) 2) :rule-classes nil))
