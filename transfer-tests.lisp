; Run in BOTH ACL2 and ACL2(r), after including transfer.
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
(assert-event (r2a-interface-error '((local (include-book "unchecked")))))
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
