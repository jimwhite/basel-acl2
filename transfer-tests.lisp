; Interface-checker tests. Certified in BOTH ACL2 and ACL2(r).
(in-package "ACL2")
(include-book "transfer")

; Matt's example: the exported formula alone passes the term vocabulary,
; but the full interface MUST fail at the LOCAL witness definition.
(assert-event
 (r2a-termp '(equal (* (my-sqrt-2) (my-sqrt-2)) 2) '(my-sqrt-2)))
(assert-event
 (equal
  (car (r2a-interface-error
        '((encapsulate ((my-sqrt-2 () t))
            (local (defun my-sqrt-2 () (sqrt 2)))
            (defthm bad (equal (* (my-sqrt-2) (my-sqrt-2)) 2))))))
  :nonportable-definition))

; ACL2(r)'s actual square-root spelling, under additional LOCAL/ENCAPSULATE.
(assert-event
 (r2a-interface-error
  '((encapsulate ()
      (local
       (encapsulate ((hidden-root () t))
         (local (defun hidden-root () (acl2-sqrt 2)))
         (defthm hidden-bad (equal (* (hidden-root) (hidden-root)) 2))))))))

; A nonportable LOCAL theorem is rejected even when it exports nothing.
(assert-event
 (r2a-interface-error
  '((encapsulate ()
      (local (defthm hidden-real (realp (acl2-pi))))))))

; Macro/event escape hatches and introduced constants fail closed.
(assert-event (r2a-interface-error '((make-event '(defthm bad nil)))))
(assert-event (r2a-interface-error '((skip-proofs (defthm bad nil)))))
; The line break keeps cert.pl from scanning quoted data as a dependency.
(assert-event (r2a-interface-error '((local (include-book
                                            "unchecked")))))
(assert-event (r2a-interface-error '((defun-std hidden () (acl2-pi)))))
(assert-event (r2a-interface-error '((defthm bad (equal *hidden* 2)))))
(assert-event (r2a-interface-error '((defthm bad (unknown-macro x)))))
(assert-event
 (r2a-interface-error
  '((encapsulate ((missing () t)) (defthm bad (equal (missing) 2))))))

; LOCAL helpers are available within the scope, but not after it.
(assert-event
 (not (r2a-interface-error
       '((encapsulate ((portable-half (x) t))
           (local (defun portable-half (x) (/ (ifix x) 2)))
           (local (defun portable-helper (x) (portable-half x)))
           (local (defthm helper-rational (rationalp (portable-helper x))))
           (defthm half-rational (rationalp (portable-half x))))))))
(assert-event
 (r2a-interface-error
  '((encapsulate () (local (defun hidden-helper (x) x)))
    (defthm bad (equal (hidden-helper x) x)))))

; Do not transfer a later theorem about an already abstract function.
; Over ACL2(r), the constraint below implies c=0 by choosing x=sqrt(2).
; Over ACL2 it is vacuous. A rational witness alone does not fix that!
(assert-event
 (r2a-interface-error
  '((encapsulate ((portable-c () t))
      (local (defun portable-c () 0))
      (defthm conditional-c
        (implies (equal (* x x) 2) (equal (portable-c) 0))))
    (defthm cannot-transfer-this (equal (portable-c) 0)))))

;;; Projection of proof-only events (R2A-PROJECT-EVENTS)
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

;;; Portable sibling books, as expanded by R2A-EXPAND-EVENTS

; The book's definitions extend the vocabulary of later events.
(assert-event
 (not (r2a-interface-error
       '((r2a-included-book "defs" (defun two () 2))
         (defthm two-rational (rationalp (two)))))))
; Its events are checked, and its LOCAL definitions do not escape.
(assert-event
 (r2a-interface-error
  '((r2a-included-book "defs" (defun root () (acl2-sqrt 2))))))
(assert-event
 (r2a-interface-error
  '((r2a-included-book "defs" (local (defun two () 2)))
    (defthm two-rational (rationalp (two))))))
