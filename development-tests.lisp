(in-package "ACL2")
(include-book "transfer")
; Quoted INCLUDE-BOOK data below is split across lines so that cert.pl does
; not treat it as a dependency (cert.pl scans text, not code).

; Proof-only analytic locals are projected away, including through a trivial
; encapsulate. They are still submitted to the source prover unchanged.
(assert-event
 (equal
  (r2a-project-events
   '((local (include-book
            "nonstd/nsa/sqrt" :dir :system))
     (encapsulate ()
       (local (defun scratch-root () (acl2-sqrt 2)))
       (defun rational-endpoint () 3/2))) nil)
  '((encapsulate () (defun rational-endpoint () 3/2)))))
(assert-event
 (not
  (r2a-interface-error
   (r2a-project-events
    '((local (include-book
            "nonstd/nsa/sqrt" :dir :system))
      (defun rational-endpoint () 3/2)
      (defthm endpoint-rational (rationalp (rational-endpoint)))) nil))))

; Matt's witness must remain visible to the checker.
(assert-event
 (r2a-interface-error
  (r2a-project-events
   '((encapsulate ((my-sqrt-2 () t))
       (local (defun my-sqrt-2 () (acl2-sqrt 2)))
       (defthm bad (equal (* (my-sqrt-2) (my-sqrt-2)) 2)))) nil)))

; A trivial nested scope must not hide a witness's nonportable helper.
(assert-event
 (r2a-interface-error
  (r2a-project-events
   '((encapsulate ((my-root () t))
       (local (encapsulate ()
                (defun root-helper () (acl2-sqrt 2))))
       (local (defun my-root () (root-helper)))
       (defthm bad (equal (* (my-root) (my-root)) 2)))) nil)))

; Dropping a local definition must not make its name portable elsewhere.
(assert-event
 (r2a-interface-error
  (r2a-project-events
   '((local (defun root-helper () (acl2-sqrt 2)))
     (defun exported-root () (root-helper))) nil)))

; Choice needs an additional domain argument; this implementation rejects it.
(assert-event
 (r2a-interface-error
  (r2a-project-events
   '((local (include-book
            "nonstd/nsa/sqrt" :dir :system))
     (defchoose chosen-root (x) () (equal (* x x) 2))
     (defthm bad (equal (* (chosen-root) (chosen-root)) 2))) nil)))

; Rational witnesses are retained, rather than rejected categorically.
(assert-event
 (not
  (r2a-interface-error
   (r2a-project-events
    '((encapsulate ((rational-half (x) t))
        (local (defun rational-half (x) (/ (ifix x) 2)))
        (defthm half-rational (rationalp (rational-half x))))) nil))))
