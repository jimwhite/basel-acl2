; ACL2(r) -> ACL2 event transfer, with a conservative portable interface.
; SPDX-License-Identifier: MIT
(in-package "ACL2")

; Usage.  An ACL2(r) book whose entire content is
;
;   (in-package "ACL2")
;   (include-book "transfer")
;   (r2a-export NAME EVENT ...)
;
; proves EVENT ... in ACL2(r) when it is certified.  An ordinary ACL2 book
; then calls (R2A-IMPORT "<that book>"), which reads the SAME source file,
; derives the same portable interface with the same code, checks it, and
; admits it.  No intermediate file is written by either side.
;
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
    ((eq (car event) 'r2a-included-book)
     ; A portable sibling book, already read by R2A-EXPAND-EVENTS. Its
     ; events are checked as a trivial encapsulate: only its non-LOCAL
     ; definitions extend the vocabulary.
     (if (and (<= 2 (len event)) (stringp (cadr event)))
         (r2a-check-event (list* 'encapsulate nil (cddr event)) functions)
       (mv (list :malformed-included-book event) functions nil)))
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
     (r2a-included-book (list 'include-book (cadr event)))
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
; The strict checker then checks this entire retained subtree.
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

;;; Reading book sources

(defun r2a-read-objects (channel acc state)
  (declare (xargs :stobjs state))
  (mv-let (eof object state) (read-object channel state)
    (if eof (mv (reverse acc) state)
      (r2a-read-objects channel (cons object acc) state))))

; ACL2 and ACL2(r) read #+/#- differently, and the transfer depends on both
; systems reading the same events.  Reject such text anywhere, even in
; comments or strings: this is deliberately conservative.
(defun r2a-reader-conditional-p (channel prev state)
  (declare (xargs :stobjs state))
  (mv-let (c state) (read-char$ channel state)
    (cond ((null c) (mv nil state))
          ((and (eql prev #\#) (member c '(#\+ #\-))) (mv t state))
          (t (r2a-reader-conditional-p channel c state)))))

; Return the forms after the initial (in-package "ACL2") of PATH.
(defun r2a-read-book (path state)
  (declare (xargs :stobjs state))
  (let ((file (extend-pathname (cbd) path state)))
    (mv-let (channel state) (open-input-channel file :character state)
      (if (not channel) (er soft 'r2a-read-book "Cannot read ~x0." file)
        (mv-let (conditionalp state) (r2a-reader-conditional-p channel nil state)
          (let ((state (close-input-channel channel state)))
            (if conditionalp
                (er soft 'r2a-read-book
                    "~x0 contains a #+ or #- reader conditional." file)
              (mv-let (channel state) (open-input-channel file :object state)
                (if (not channel) (er soft 'r2a-read-book "Cannot read ~x0." file)
                  (mv-let (forms state) (r2a-read-objects channel nil state)
                    (let ((state (close-input-channel channel state)))
                      (if (equal (car forms) '(in-package "ACL2"))
                          (value (cdr forms))
                        (er soft 'r2a-read-book
                            "~x0 does not begin with (in-package \"ACL2\")."
                            file)))))))))))))

(defun r2a-book-name-p (x)
  (and (stringp x) (< 0 (length x))
       (not (equal (char x 0) #\/))
       (not (search ".lisp" x))))

(defun r2a-sibling-name-p (x)
  (and (r2a-book-name-p x) (not (search "/" x))))

; Directory prefix of a relative book name, e.g. "a/b" -> "a/".
(defun r2a-directory-part (name)
  (let ((pos (search "/" name :from-end t)))
    (if pos (subseq name 0 (1+ pos)) "")))

; Replace each retained (INCLUDE-BOOK "name") by (R2A-INCLUDED-BOOK "name"
; EVENT ...), the events of that sibling book, so that the checker sees and
; checks them.  Only plain sibling books are supported; LOCAL proof-only
; includes were already removed by R2A-PROJECT-EVENTS.
(mutual-recursion
 (defun r2a-expand-event (event dir seen state)
   (declare (xargs :stobjs state))
   (cond
    ((not (and (consp event) (true-listp event))) (value event))
    ((eq (car event) 'r2a-included-book)
     (er soft 'r2a-expand "R2A-INCLUDED-BOOK is reserved: ~x0" event))
    ((eq (car event) 'include-book)
     (let* ((name (cadr event))
            (book (and (stringp name) (concatenate 'string dir name))))
       (cond
        ((not (and (equal (len event) 2) (r2a-sibling-name-p name)))
         (er soft 'r2a-expand
             "A retained include-book must name a sibling book without ~
              options: ~x0" event))
        ((member-equal book seen)
         (er soft 'r2a-expand "Circular include of ~x0." book))
        (t (er-let* ((forms (r2a-read-book (concatenate 'string book ".lisp")
                                           state))
                     (events (r2a-expand-events (r2a-project-events forms nil)
                                                dir (cons book seen) state)))
             (value (list* 'r2a-included-book book events)))))))
    ((and (eq (car event) 'local) (consp (cdr event)))
     (er-let* ((x (r2a-expand-event (cadr event) dir seen state)))
       (value (list* 'local x (cddr event)))))
    ((and (eq (car event) 'encapsulate) (consp (cdr event)))
     (er-let* ((xs (r2a-expand-events (cddr event) dir seen state)))
       (value (list* 'encapsulate (cadr event) xs))))
    (t (value event))))
 (defun r2a-expand-events (events dir seen state)
   (declare (xargs :stobjs state))
   (if (atom events) (value events)
     (er-let* ((x (r2a-expand-event (car events) dir seen state))
               (xs (r2a-expand-events (cdr events) dir seen state)))
       (value (cons x xs))))))

; The checked interface of EVENTS: projected, expanded, and checked.
(defun r2a-interface (ctx events dir state)
  (declare (xargs :stobjs state))
  (if (not (true-listp events))
      (er soft ctx "Malformed event list: ~x0" events)
    (er-let* ((interface (r2a-expand-events (r2a-project-events events nil)
                                            dir nil state)))
      (let ((err (r2a-interface-error interface)))
        (if err
            (er soft ctx
                "Rejected retained definitions, witnesses, or theorem: ~x0"
                err)
          (value interface))))))

;;; ACL2(r): prove and record an export

(defun r2a-record-export (name interface state)
  (declare (xargs :stobjs state))
  (cond ((not (r2a-clean-worldp state))
         (er soft 'r2a-export
             "The completed source proof used trust tags, skipped proofs, ~
              redefinition, or added axioms."))
        ((r2a-interface-error interface)
         (er soft 'r2a-export "Invalid retained interface."))
        (t (value `(table r2a-exports ',name
                          ',(r2a-strip-proofs interface))))))

(defun r2a-export-fn (name events state)
  (declare (xargs :stobjs state))
  (cond ((not (symbolp name))
         (er soft 'r2a-export "The export name must be a symbol: ~x0" name))
        ((not (r2a-clean-worldp state))
         (er soft 'r2a-export
             "Requires ACL2(r), proofs enabled, and no trust tags, skipped ~
              proofs, redefinition, or added axioms."))
        (t
         (er-let* ((interface (r2a-interface 'r2a-export events "" state)))
           (value
            `(progn
               ; Prove the ORIGINAL events, with their analytic local helpers.
               ; PROGN, not ENCAPSULATE, so retained INCLUDE-BOOKs are legal;
               ; the export book's shape makes this the book's only event.
               (progn ,@events)
               ; Record only after both passes and a fresh trust-state check.
               (make-event (r2a-record-export ',name ',interface state))))))))

(defmacro r2a-export (name &rest events)
  `(make-event (r2a-export-fn ',name ',events state)))

;;; Ordinary ACL2: import an export from its ACL2(r) source book

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
     ; The sibling book is certified and included natively in ACL2.
     (r2a-included-book (list 'include-book (cadr event)))
     (otherwise event)))
 (defun r2a-import-events (events functions)
   (if (endp events) nil
     (mv-let (err fs exported) (r2a-check-event (car events) functions)
       (declare (ignore err exported))
       (cons (r2a-import-event (car events) functions)
             (r2a-import-events (cdr events) fs))))))

; The source book must consist of exactly these forms, so that no other
; event in it can affect what ACL2(r) proves.
(defun r2a-export-book-p (forms)
  (and (equal (len forms) 2)
       ; Built with LIST so that cert.pl does not read it as a dependency.
       (equal (car forms) (list 'include-book "transfer"))
       (true-listp (cadr forms))
       (<= 2 (len (cadr forms)))
       (eq (car (cadr forms)) 'r2a-export)
       (symbolp (cadr (cadr forms)))))

; Return (NAME . INTERFACE) for the export in the source book BOOK.
(defun r2a-source-export (book state)
  (declare (xargs :stobjs state))
  (cond
   ((not (r2a-book-name-p book))
    (er soft 'r2a-import "Expected a relative book name, got ~x0." book))
   ((not (equal (current-package state) "ACL2"))
    (er soft 'r2a-import "Import from the \"ACL2\" package."))
   (t
    (er-let* ((forms (r2a-read-book (concatenate 'string book ".lisp") state)))
      (if (not (r2a-export-book-p forms))
          (er soft 'r2a-import
              "~x0 must contain only (in-package \"ACL2\"), (include-book ~
               \"transfer\"), and one R2A-EXPORT form." book)
        (let ((export (cadr forms)))
          (er-let* ((interface (r2a-interface 'r2a-import (cddr export)
                                              (r2a-directory-part book)
                                              state)))
            (value (cons (cadr export) interface)))))))))

(defun r2a-import-fn (book state)
  (declare (xargs :stobjs state))
  (if *r2a-real-build*
      (er soft 'r2a-import "Run the importer in ordinary ACL2.")
    (er-let* ((export (r2a-source-export book state)))
      (value `(progn
                ,@(r2a-import-events (cdr export) nil)
                (table r2a-exports ',(car export)
                       ',(r2a-strip-proofs (cdr export))))))))

(defmacro r2a-import (book)
  `(make-event (r2a-import-fn ,book state)))

(logic)
