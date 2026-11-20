; R2A-IMPORT fixture: an export book may not contain other events, since they
; could change how the exported events are proved.
(in-package "ACL2")
(include-book "transfer")
(defun extra-event () t)
(r2a-export extra-event
  (defthm trivially-true (equal 1 1) :rule-classes nil))
