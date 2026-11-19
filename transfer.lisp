; ACL2(r) -> ACL2 event transfer, with a conservative portable interface.
; SPDX-License-Identifier: MIT
(in-package "ACL2")

; These utilities are executable checking/generation code, not a verified
; metatheorem.  The importer explicitly registers trusted clause processors.
(program)
(set-state-ok t)

(defconst *r2a-real-build*
  #+non-standard-analysis t
  #-non-standard-analysis nil)

; A small, reviewed vocabulary whose evaluation on ordinary ACL2 objects
; agrees in the two logics and stays in the ordinary ACL2 universe.
; Do NOT replace this by ACL2(r)'s classicalp: sqrt is classical too.
(defconst *r2a-operators*
  '(if equal not implies and or iff
    cons car cdr consp atom endp list list* append revappend
    symbolp stringp characterp rationalp complex-rationalp acl2-numberp
    integerp natp posp zp nfix ifix fix rfix
    binary-+ binary-* unary-- unary-/ + - * / 1+ 1-
    < <= > >= = /= expt abs numerator denominator
    realpart imagpart complex len))

(defun r2a-objectp (x)
  (if (consp x)
      (and (r2a-objectp (car x)) (r2a-objectp (cdr x)))
    (or (symbolp x) (stringp x) (characterp x)
        (rationalp x) (complex-rationalp x))))

(mutual-recursion
 (defun r2a-termp (x functions)
   (cond ((atom x)
          (if (symbolp x)
              (or (eq x t) (eq x nil) (legal-variablep x))
            (r2a-objectp x)))
         ((not (true-listp x)) nil)
         ((eq (car x) 'quote)
          (and (equal (len x) 2) (r2a-objectp (cadr x))))
         ((member-eq (car x) '(let let*))
          (and (equal (len x) 3)
               (r2a-bindingsp (cadr x) functions)
               (r2a-termp (caddr x) functions)))
         (t (and (symbolp (car x))
                 (or (member-eq (car x) *r2a-operators*)
                     (member-eq (car x) functions))
                 (r2a-terms-p (cdr x) functions)))))
 (defun r2a-terms-p (xs functions)
   (if (atom xs) (null xs)
     (and (r2a-termp (car xs) functions)
          (r2a-terms-p (cdr xs) functions))))
 (defun r2a-bindingsp (xs functions)
   (if (atom xs) (null xs)
     (and (true-listp (car xs)) (equal (len (car xs)) 2)
          (legal-variablep (caar xs))
          (r2a-termp (cadar xs) functions)
          (r2a-bindingsp (cdr xs) functions)))))

(defun r2a-declarationp (x functions)
  ; Only a measure is accepted.  Other declarations require explicit support;
  ; in particular, :mode, :stobjs, and termination-skipping options are absent.
  (and (true-listp x) (equal (len x) 2) (eq (car x) 'declare)
       (true-listp (cadr x)) (equal (len (cadr x)) 3)
       (eq (caadr x) 'xargs) (eq (cadadr x) :measure)
       (r2a-termp (car (cddadr x)) functions)))

(defun r2a-theorem-optionsp (xs)
  (if (atom xs) (null xs)
    (and (consp (cdr xs))
         (member-eq (car xs) '(:hints :rule-classes))
         (r2a-theorem-optionsp (cddr xs)))))

(defun r2a-signaturesp (xs)
  (if (atom xs) (null xs)
    (and (true-listp (car xs)) (equal (len (car xs)) 3)
         (symbolp (caar xs)) (symbol-listp (cadar xs))
         (eq (caddar xs) t)
         (r2a-signaturesp (cdr xs)))))

(defun r2a-direct-witnessp (name events)
  (if (endp events) nil
    (or (and (eq (caar events) 'local)
             (eq (caadar events) 'defun)
             (eq (cadadr (car events)) name))
        (r2a-direct-witnessp name (cdr events)))))

(defun r2a-witnesses-p (signatures events)
  (if (endp signatures) t
    (and (r2a-direct-witnessp (caar signatures) events)
         (r2a-witnesses-p (cdr signatures) events))))

; Return an offending event (nil on success), visible function names, and
; newly exported function names. LOCAL extends the first list, not the last.
; All local events are checked, including local theorems and local witnesses.
(mutual-recursion
 (defun r2a-check-event (event functions)
   (cond
    ((not (and (true-listp event) (consp event)))
     (mv (list :malformed event) functions nil))
    ((eq (car event) 'defun)
     (let* ((name (cadr event)) (fs (cons name functions)))
       (if (and (member-equal (len event) '(4 5))
                (symbolp name) (symbol-listp (caddr event))
                (or (equal (len event) 4)
                    (r2a-declarationp (cadddr event) functions))
                (r2a-termp (car (last event)) fs))
           (mv nil fs (list name))
         (mv (list :nonportable-definition event) functions nil))))
    ((eq (car event) 'defthm)
     (if (and (<= 3 (len event)) (symbolp (cadr event))
              (r2a-termp (caddr event) functions)
              (r2a-theorem-optionsp (cdddr event)))
         (mv nil functions nil)
       (mv (list :nonportable-theorem event) functions nil)))
    ((eq (car event) 'local)
     (if (equal (len event) 2)
         (mv-let (err fs exported) (r2a-check-event (cadr event) functions)
           (declare (ignore exported))
           (mv err fs nil))
       (mv (list :malformed-local event) functions nil)))
    ((eq (car event) 'encapsulate)
     (if (and (<= 2 (len event)) (r2a-signaturesp (cadr event))
              (r2a-witnesses-p (cadr event) (cddr event)))
         (let ((sigs (strip-cars (cadr event))))
           (mv-let (err fs exported)
             (r2a-check-events (cddr event) (append sigs functions))
             (declare (ignore fs))
             ; After abstraction, even a portable witness does NOT establish
             ; that arbitrary target interpretations extend to ACL2(r).
             ; Keep constrained functions (and helpers depending on them)
             ; out of the vocabulary of subsequent transferred theorems.
             (let ((out (if sigs nil exported)))
               (mv err (append out functions) out))))
       (mv (list :unsupported-signature-or-missing-witness event)
           functions nil)))
    (t (mv (list :unsupported-event event) functions nil))))
 (defun r2a-check-events (events functions)
   (if (atom events)
       (mv (and events (list :improper-event-list events)) functions nil)
     (mv-let (err fs exported) (r2a-check-event (car events) functions)
       (if err (mv err fs exported)
         (mv-let (err2 fs2 exported2) (r2a-check-events (cdr events) fs)
           (mv err2 fs2 (union-eq exported exported2))))))))

(defun r2a-interface-error (events)
  (mv-let (err fs exported) (r2a-check-events events nil)
    (declare (ignore fs exported))
    err))

(mutual-recursion
 (defun r2a-strip-proof (event)
   (case (car event)
     (defthm (list 'defthm (cadr event) (caddr event) :rule-classes nil))
     (local (list 'local (r2a-strip-proof (cadr event))))
     (encapsulate (list* 'encapsulate (cadr event)
                        (r2a-strip-proofs (cddr event))))
     (otherwise event)))
 (defun r2a-strip-proofs (events)
   (if (endp events) nil
     (cons (r2a-strip-proof (car events)) (r2a-strip-proofs (cdr events))))))

(defun r2a-clean-worldp (state)
  (and *r2a-real-build*
       (not (f-get-global 'ld-skip-proofsp state))
       (not (f-get-global 'ld-redefinition-action state))
       (not (global-val 'skip-proofs-seen (w state)))
       (not (global-val 'redef-seen (w state)))
       (not (global-val 'ttags-seen (w state)))
       (equal (global-val 'nonconstructive-axiom-names (w state))
              (global-val 'nonconstructive-axiom-names
                          (scan-to-landmark-number
                           'event-landmark
                           (global-val 'event-number-baseline (w state))
                           (w state))))))

; Discard proof-only LOCAL events outside nontrivial encapsulates. Inside a
; nontrivial encapsulate retain EVERYTHING: in particular its witnesses.
; The existing strict checker then checks this entire retained subtree.
(mutual-recursion
 (defun r2a-project-event (event inside-signature)
   (cond
    (inside-signature (list event))
    ((and (true-listp event) (equal (len event) 2)
          (eq (car event) 'local)) nil)
    ((and (true-listp event) (<= 2 (len event))
          (eq (car event) 'encapsulate))
     (list (list* 'encapsulate (cadr event)
                  (r2a-project-events (cddr event) (and (cadr event) t)))))
    (t (list event))))
 (defun r2a-project-events (events inside-signature)
   (if (atom events) events
     (append (r2a-project-event (car events) inside-signature)
             (r2a-project-events (cdr events) inside-signature)))))

(defun r2a-record-export (name events state)
  (declare (xargs :stobjs state))
  (cond ((not (r2a-clean-worldp state))
         (er soft 'r2a-export
             "The completed source proof used trust tags, skipped proofs, redefinition, or added axioms."))
        ((r2a-interface-error events)
         (er soft 'r2a-export "Invalid retained interface."))
        (t (value `(table r2a-exports ',name ',(r2a-strip-proofs events))))))

(defun r2a-write-receipt (path events state)
  (declare (xargs :stobjs state))
  (if (not (r2a-clean-worldp state))
      (er soft 'r2a-export "Requires ACL2(r), proofs enabled, and no skipped proofs or trust tags.")
    (mv-let (channel state) (open-output-channel path :character state)
      (if (not channel) (er soft 'r2a-export "Cannot write ~x0." path)
        (let* ((state (print-object$ (list :r2a-v1 (f-get-global 'acl2-version state)
                                         (r2a-strip-proofs events)) channel state))
               (state (close-output-channel channel state)))
          (value :r2a-exported))))))

(defun r2a-export-event (name events state)
  (declare (xargs :stobjs state))
  (let ((err (r2a-interface-error events)))
    (cond (err (er soft 'r2a-export "Rejected portable interface: ~x0" err))
          ((not (r2a-clean-worldp state))
           (er soft 'r2a-export "Requires a clean ACL2(r) proof world."))
          (t
           ; Record only AFTER both passes have succeeded. Writing a file
           ; takes place in a separate top-level command, never in MAKE-EVENT.
           (value `(progn
                     (encapsulate () ,@events)
                     (make-event (r2a-record-export ',name ',events state))))))))

(defmacro r2a-export (name &rest events)
  `(make-event (r2a-export-event ',name ',events state)))

(defun r2a-export-development-event (name events state)
  (declare (xargs :stobjs state))
  (let* ((interface (r2a-project-events events nil))
         (err (r2a-interface-error interface)))
    (cond (err (er soft 'r2a-export-development
                  "Rejected retained definitions, witnesses, or theorem: ~x0" err))
          ((not (r2a-clean-worldp state))
           (er soft 'r2a-export-development "Requires a clean ACL2(r) proof world."))
          (t
           (value
            `(progn
               ; Prove the ORIGINAL events, with their analytic local helpers.
               (encapsulate () ,@events)
               ; Only record after both passes and a fresh trust-state check.
               (make-event (r2a-record-export ',name ',interface state))))))))

(defmacro r2a-export-development (name &rest events)
  `(make-event (r2a-export-development-event ',name ',events state)))

(defun r2a-write-export (name path state)
  (declare (xargs :stobjs state))
  (let ((entry (assoc-eq name (table-alist 'r2a-exports (w state)))))
    (if (or (not entry) (r2a-interface-error (cdr entry)))
        (er soft 'r2a-write-export "No checked export named ~x0." name)
      (mv-let (channel state) (open-input-channel path :object state)
        (if channel
            (let ((state (close-input-channel channel state)))
              (er soft 'r2a-write-export "Refusing to overwrite receipt ~x0." path))
          (r2a-write-receipt path (cdr entry) state))))))

; Every theorem gets its own predicate and exact singleton-clause processor.
; This avoids assuming that the theorem's surface syntax equals a clause.
; The wrapper and all visible interface functions are explicit supporters.
(defun r2a-import-theorem (event functions state)
  (declare (xargs :stobjs state))
  (let* ((name (cadr event)) (formula (caddr event))
         (pred (add-suffix name "$R2A-PRED"))
         (cp (add-suffix name "$R2A-CP"))
         (lemma (add-suffix name "$R2A-FACT")))
    (er-let* ((term (translate formula t t t 'r2a-import (w state) state)))
      (let* ((vars (all-vars term)) (call (cons pred vars)))
        (value
         `(encapsulate ()
            (local (defun ,pred ,vars ,formula))
            (local (defun ,cp (clause)
                     (if (equal clause ',(list call)) nil (list clause))))
            (local
             (define-trusted-clause-processor ,cp ,(cons pred functions)
               :ttag :acl2r-checked-transfer))
            (local
             (defthm ,lemma ,call
               :hints (("Goal" :clause-processor (,cp clause)))
               :rule-classes nil))
            (defthm ,name ,formula
              :hints (("Goal" :use ,lemma
                       :in-theory (enable ,pred)))
              :rule-classes nil)))))))

(mutual-recursion
 (defun r2a-import-event (event functions)
   (case (car event)
     (defthm `(make-event (r2a-import-theorem ',event ',functions state)))
     (local (list 'local (r2a-import-event (cadr event) functions)))
     (encapsulate
      (list* 'encapsulate (cadr event)
             (r2a-import-events (cddr event)
                                (append (strip-cars (cadr event)) functions))))
     (otherwise event)))
 (defun r2a-import-events (events functions)
   (if (endp events) nil
     (mv-let (err fs exported) (r2a-check-event (car events) functions)
       (declare (ignore err exported))
       (cons (r2a-import-event (car events) functions)
             (r2a-import-events (cdr events) fs))))))

(defun r2a-import-file (path state)
  (declare (xargs :stobjs state))
  (if *r2a-real-build*
      (er soft 'r2a-import "Run the importer in ordinary ACL2.")
    (mv-let (channel state) (open-input-channel path :object state)
      (if (not channel) (er soft 'r2a-import "Cannot read ~x0." path)
        (mv-let (eof receipt state) (read-object channel state)
          (mv-let (eof2 extra state) (read-object channel state)
            (declare (ignore extra))
            (let ((state (close-input-channel channel state)))
              (if (or eof (not eof2) (not (true-listp receipt))
                      (not (equal (len receipt) 3))
                      (not (eq (car receipt) :r2a-v1))
                      (not (stringp (cadr receipt))))
                  (er soft 'r2a-import "Malformed transfer receipt.")
                (let* ((events (caddr receipt))
                       (err (r2a-interface-error events)))
                  (if err (er soft 'r2a-import "Rejected portable interface: ~x0" err)
                    (value (cons 'progn (r2a-import-events events nil)))))))))))))

(defmacro r2a-import (path)
  `(make-event (r2a-import-file ,path state)))

(logic)
