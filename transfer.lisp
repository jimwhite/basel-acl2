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
; Every function in this book is in :LOGIC mode with verified guards, so its
; termination is proved and it executes as compiled Common Lisp without guard
; violations on any input.  Theorems at the end state the vocabulary policy.
; This is NOT a verified transfer metatheorem: the importer still registers
; trusted clause processors, and their soundness rests on the argument in
; TRANSFER.md.

(include-book "std/io/read-file-objects" :dir :system)
(include-book "std/basic/two-nats-measure" :dir :system)
(local (include-book "tools/flag" :dir :system))

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
  (declare (xargs :guard t))
  (if (consp x)
      (and (r2a-objectp (car x)) (r2a-objectp (cdr x)))
    (or (symbolp x) (stringp x) (characterp x)
        (rationalp x) (complex-rationalp x))))

(mutual-recursion
 (defun r2a-termp (x functions)
   (declare (xargs :guard (symbol-listp functions)))
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
   (declare (xargs :guard (symbol-listp functions)))
   (if (atom xs) (null xs)
     (and (r2a-termp (car xs) functions)
          (r2a-terms-p (cdr xs) functions))))
 (defun r2a-bindingsp (xs functions)
   (declare (xargs :guard (symbol-listp functions)))
   (if (atom xs) (null xs)
     (and (true-listp (car xs)) (equal (len (car xs)) 2)
          (legal-variablep (caar xs))
          (r2a-termp (cadar xs) functions)
          (r2a-bindingsp (cdr xs) functions)))))

(defun r2a-declarationp (x functions)
  ; Only a measure is accepted.  Other declarations require explicit support;
  ; in particular, :mode, :stobjs, and termination-skipping options are absent.
  (declare (xargs :guard (symbol-listp functions)))
  (and (true-listp x) (equal (len x) 2) (eq (car x) 'declare)
       (true-listp (cadr x)) (equal (len (cadr x)) 3)
       (eq (car (cadr x)) 'xargs) (eq (cadr (cadr x)) :measure)
       (r2a-termp (caddr (cadr x)) functions)))

(defun r2a-theorem-optionsp (xs)
  (declare (xargs :guard t))
  (if (atom xs) (null xs)
    (and (consp (cdr xs))
         (member-eq (car xs) '(:hints :rule-classes))
         (r2a-theorem-optionsp (cddr xs)))))

(defun r2a-signaturesp (xs)
  (declare (xargs :guard t))
  (if (atom xs) (null xs)
    (and (true-listp (car xs)) (equal (len (car xs)) 3)
         (symbolp (caar xs)) (symbol-listp (cadar xs))
         (eq (caddar xs) t)
         (r2a-signaturesp (cdr xs)))))

(defthm r2a-signaturesp-forward
  (implies (r2a-signaturesp xs)
           (and (alistp xs) (symbol-listp (strip-cars xs))))
  :rule-classes :forward-chaining)

; Is EVENT of the form (LOCAL (DEFUN NAME ...))?
(defun r2a-local-defun-of-p (name event)
  (declare (xargs :guard t))
  (and (true-listp event) (equal (len event) 2) (eq (car event) 'local)
       (true-listp (cadr event)) (<= 2 (len (cadr event)))
       (eq (car (cadr event)) 'defun)
       (equal (cadr (cadr event)) name)))

(defun r2a-direct-witnessp (name events)
  (declare (xargs :guard t))
  (if (atom events) nil
    (or (r2a-local-defun-of-p name (car events))
        (r2a-direct-witnessp name (cdr events)))))

(defun r2a-witnesses-p (signatures events)
  (declare (xargs :guard t))
  (if (atom signatures) t
    (and (consp (car signatures))
         (r2a-direct-witnessp (caar signatures) events)
         (r2a-witnesses-p (cdr signatures) events))))

; Return an offending event (nil on success), visible function names, and
; newly exported function names. LOCAL extends the first list, not the last.
; All local events are checked, including local theorems and local witnesses.
(mutual-recursion
 (defun r2a-check-event (event functions)
   (declare (xargs :guard (symbol-listp functions)
                   :verify-guards nil
                   :measure (+ 2 (* 3 (acl2-count event)))))
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
     (cond
      ((not (and (<= 2 (len event)) (r2a-signaturesp (cadr event))
                 (r2a-witnesses-p (cadr event) (cddr event))))
       (mv (list :unsupported-signature-or-missing-witness event)
           functions nil))
      ((cadr event)
       ; After abstraction, even a portable witness does NOT establish that
       ; arbitrary target interpretations extend to ACL2(r).  Keep
       ; constrained functions (and helpers depending on them) out of the
       ; vocabulary of subsequent transferred theorems.
       (mv-let (err fs exported)
         (r2a-check-events (cddr event)
                           (append (strip-cars (cadr event)) functions))
         (declare (ignore fs exported))
         (mv err functions nil)))
      (t (r2a-check-scope (cddr event) functions))))
    ((eq (car event) 'r2a-included-book)
     ; A portable sibling book, already read by R2A-EXPAND-EVENTS. Its
     ; events are checked as a trivial encapsulate: only its non-LOCAL
     ; definitions extend the vocabulary.
     (if (and (<= 2 (len event)) (stringp (cadr event)))
         (r2a-check-scope (cddr event) functions)
       (mv (list :malformed-included-book event) functions nil)))
    (t (mv (list :unsupported-event event) functions nil))))
 ; A trivial scope (encapsulate () ...): its non-LOCAL definitions survive.
 (defun r2a-check-scope (events functions)
   (declare (xargs :guard (symbol-listp functions) :verify-guards nil
                   :measure (+ 1 (* 3 (acl2-count events)))))
   (mv-let (err fs exported) (r2a-check-events events functions)
     (declare (ignore fs))
     (mv err (append exported functions) exported)))
 (defun r2a-check-events (events functions)
   (declare (xargs :guard (symbol-listp functions) :verify-guards nil
                   :measure (* 3 (acl2-count events))))
   (if (atom events)
       (mv (and events (list :improper-event-list events)) functions nil)
     (mv-let (err fs exported) (r2a-check-event (car events) functions)
       (if err (mv err fs exported)
         (mv-let (err2 fs2 exported2) (r2a-check-events (cdr events) fs)
           (mv err2 fs2 (append exported exported2))))))))

(local
 (defthm symbol-listp-of-append
   (implies (and (symbol-listp x) (symbol-listp y))
            (symbol-listp (append x y)))))

(local (make-flag r2a-check-event))

(local
 (defthm-flag-r2a-check-event
   (defthm r2a-check-event-types
     (implies (symbol-listp functions)
              (let ((ret (r2a-check-event event functions)))
                (and (symbol-listp (mv-nth 1 ret))
                     (symbol-listp (mv-nth 2 ret)))))
     :flag r2a-check-event)
   (defthm r2a-check-scope-types
     (implies (symbol-listp functions)
              (let ((ret (r2a-check-scope events functions)))
                (and (symbol-listp (mv-nth 1 ret))
                     (symbol-listp (mv-nth 2 ret)))))
     :flag r2a-check-scope)
   (defthm r2a-check-events-types
     (implies (symbol-listp functions)
              (let ((ret (r2a-check-events events functions)))
                (and (symbol-listp (mv-nth 1 ret))
                     (symbol-listp (mv-nth 2 ret)))))
     :flag r2a-check-events)))

(verify-guards r2a-check-event)

(defun r2a-interface-error (events)
  (declare (xargs :guard t))
  (mv-let (err fs exported) (r2a-check-events events nil)
    (declare (ignore fs exported))
    err))

; Applied only to checked interfaces; other objects are returned unchanged.
(mutual-recursion
 (defun r2a-strip-proof (event)
   (declare (xargs :guard t))
   (cond
    ((not (and (consp event) (true-listp event))) event)
    ((and (eq (car event) 'defthm) (<= 3 (len event)))
     (list 'defthm (cadr event) (caddr event) :rule-classes nil))
    ((and (eq (car event) 'local) (consp (cdr event)))
     (list 'local (r2a-strip-proof (cadr event))))
    ((and (eq (car event) 'encapsulate) (consp (cdr event)))
     (list* 'encapsulate (cadr event) (r2a-strip-proofs (cddr event))))
    ((and (eq (car event) 'r2a-included-book) (consp (cdr event)))
     (list 'include-book (cadr event)))
    (t event)))
 (defun r2a-strip-proofs (events)
   (declare (xargs :guard t))
   (if (atom events) nil
     (cons (r2a-strip-proof (car events)) (r2a-strip-proofs (cdr events))))))

; Is there no setting of the world global NONCONSTRUCTIVE-AXIOM-NAMES (i.e.,
; no DEFAXIOM) above the event landmark numbered N?  This is a fail-closed
; version of the test CERTIFY-BOOK itself uses to detect added axioms.
(defun r2a-event-tuple-number (x)
  (declare (xargs :guard t))
  (let ((x (if (and (consp x) (eq (car x) 'local)) (cdr x) x)))
    (and (consp x)
         (if (integerp (car x)) (car x)
           (and (consp (car x)) (car (car x)))))))

(defun r2a-no-axioms-since-p (n wrld)
  (declare (xargs :guard (plist-worldp wrld)))
  (cond ((endp wrld) nil)
        ((not (eq (cadar wrld) 'global-value))
         (r2a-no-axioms-since-p n (cdr wrld)))
        ((eq (caar wrld) 'nonconstructive-axiom-names) nil)
        ((and (eq (caar wrld) 'event-landmark)
              (equal (r2a-event-tuple-number (cddar wrld)) n))
         t)
        (t (r2a-no-axioms-since-p n (cdr wrld)))))

(defun r2a-clean-worldp (state)
  (declare (xargs :stobjs state :guard (plist-worldp (w state))))
  (let ((wrld (w state)))
    (and *r2a-real-build*
         (not (f-get-global 'ld-skip-proofsp state))
         (not (f-get-global 'ld-redefinition-action state))
         (not (global-val 'skip-proofs-seen wrld))
         (not (global-val 'redef-seen wrld))
         (not (global-val 'ttags-seen wrld))
         (r2a-no-axioms-since-p (global-val 'event-number-baseline wrld)
                                wrld))))

; Discard proof-only LOCAL events outside nontrivial encapsulates. Inside a
; nontrivial encapsulate retain EVERYTHING: in particular its witnesses.
; The strict checker then checks this entire retained subtree.
(mutual-recursion
 (defun r2a-project-event (event inside-signature)
   (declare (xargs :guard t :verify-guards nil))
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
   (declare (xargs :guard t :verify-guards nil))
   (if (atom events) events
     (append (r2a-project-event (car events) inside-signature)
             (r2a-project-events (cdr events) inside-signature)))))

(local
 (defthm true-listp-of-r2a-project-event
   (true-listp (r2a-project-event event inside-signature))
   :hints (("Goal" :expand ((r2a-project-event event inside-signature))))))

(verify-guards r2a-project-events)

; Report MSG and return an error triple.  Unlike ER, this needs only STATE-P
; for guard verification, so file reading can precede it.
(defun r2a-fail (ctx msg state)
  (declare (xargs :stobjs state))
  (prog2$ (cw "~%ACL2 Error in ~x0:  ~@1~%~%" ctx msg)
          (mv t nil state)))

;;; Reading book sources

; ACL2 and ACL2(r) read #+/#- differently, and the transfer depends on both
; systems reading the same events.  Reject such text anywhere, even in
; comments or strings: this is deliberately conservative.
(defun r2a-reader-conditional-p (chars prev)
  (declare (xargs :guard (character-listp chars)))
  (cond ((endp chars) nil)
        ((and (eql prev #\#) (member (car chars) '(#\+ #\-))) t)
        (t (r2a-reader-conditional-p (cdr chars) (car chars)))))

(defun r2a-absolute-path-p (path)
  (declare (xargs :guard (stringp path)))
  (and (< 0 (length path)) (eql (char path 0) #\/)))

; Return the forms after the initial (in-package "ACL2") of PATH, which is
; absolute or relative to the connected book directory.
(defun r2a-read-book (path state)
  (declare (xargs :stobjs state :guard (stringp path)))
  (let ((dir (and (boundp-global 'connected-book-directory state)
                  (f-get-global 'connected-book-directory state)))
        (ctx 'r2a-read-book))
    (if (not (or (r2a-absolute-path-p path) (stringp dir)))
        (r2a-fail ctx (msg "The connected book directory is not set.") state)
      (let* ((file (if (r2a-absolute-path-p path) path
                     (string-append dir path)))
             (text (read-file-into-string file)))
        (cond
         ((not (stringp text))
          (r2a-fail ctx (msg "Cannot read ~x0." file) state))
         ((r2a-reader-conditional-p (coerce text 'list) nil)
          (r2a-fail ctx (msg "~x0 contains a #+ or #- reader conditional."
                             file)
                    state))
         (t (mv-let (forms state) (read-file-objects file state)
              (cond ((stringp forms) (r2a-fail ctx (msg "~@0" forms) state))
                    ((equal (car forms) '(in-package "ACL2"))
                     (value (cdr forms)))
                    (t (r2a-fail ctx
                                 (msg "~x0 does not begin with (in-package ~
                                       \"ACL2\")."
                                      file)
                                 state))))))))))

(defthm state-p1-of-r2a-read-book
  (implies (state-p1 state)
           (state-p1 (mv-nth 2 (r2a-read-book path state)))))

; Does the character list PAT occur in CHARS?
(defun r2a-occurs-p (pat chars)
  (declare (xargs :guard (and (true-listp pat) (true-listp chars))))
  (cond ((prefixp pat chars) t)
        ((endp chars) nil)
        (t (r2a-occurs-p pat (cdr chars)))))

(defun r2a-book-name-p (x)
  (declare (xargs :guard t))
  (and (stringp x) (< 0 (length x))
       (not (eql (char x 0) #\/))
       (not (r2a-occurs-p (coerce ".lisp" 'list) (coerce x 'list)))))

(defun r2a-sibling-name-p (x)
  (declare (xargs :guard t))
  (and (r2a-book-name-p x) (not (member #\/ (coerce x 'list)))))

; REV-CHARS with the characters after its first #\/ removed.
(defun r2a-drop-to-slash (rev-chars)
  (declare (xargs :guard (character-listp rev-chars)))
  (cond ((endp rev-chars) nil)
        ((eql (car rev-chars) #\/) rev-chars)
        (t (r2a-drop-to-slash (cdr rev-chars)))))

(local
 (defthm character-listp-of-r2a-drop-to-slash
   (implies (character-listp x)
            (and (character-listp (r2a-drop-to-slash x))
                 (true-listp (r2a-drop-to-slash x))))))

(local
 (defthm character-listp-of-revappend
   (implies (and (character-listp x) (character-listp y))
            (character-listp (revappend x y)))))

; Directory prefix of a relative book name, e.g. "a/b" -> "a/".
(defun r2a-directory-part (name)
  (declare (xargs :guard (stringp name)))
  (coerce (revappend (r2a-drop-to-slash (revappend (coerce name 'list) nil))
                     nil)
          'string))

; The maximum nesting of retained sibling INCLUDE-BOOKs.  Exceeding it is an
; error; it bounds the reading recursion, which proves its termination.
(defconst *r2a-max-include-depth* 64)

; Replace each retained (INCLUDE-BOOK "name") by (R2A-INCLUDED-BOOK "name"
; EVENT ...), the events of that sibling book, so that the checker sees and
; checks them.  Only plain sibling books are supported; LOCAL proof-only
; includes were already removed by R2A-PROJECT-EVENTS.
(mutual-recursion
 (defun r2a-expand-event (event dir seen depth state)
   (declare (xargs :stobjs state
                   :guard (and (stringp dir) (true-listp seen) (natp depth))
                   :verify-guards nil
                   :measure (two-nats-measure depth (acl2-count event))))
   (cond
    ((not (and (consp event) (true-listp event))) (value event))
    ((eq (car event) 'r2a-included-book)
     (r2a-fail 'r2a-expand (msg "R2A-INCLUDED-BOOK is reserved: ~x0" event)
               state))
    ((eq (car event) 'include-book)
     (let* ((name (cadr event))
            (book (and (stringp name) (string-append dir name))))
       (cond
        ((not (and (equal (len event) 2) (r2a-sibling-name-p name)))
         (r2a-fail 'r2a-expand
                   (msg "A retained include-book must name a sibling book ~
                         without options: ~x0"
                        event)
                   state))
        ((member-equal book seen)
         (r2a-fail 'r2a-expand (msg "Circular include of ~x0." book) state))
        ((zp depth)
         (r2a-fail 'r2a-expand
                   (msg "Include-books nested too deeply at ~x0." book)
                   state))
        (t (er-let* ((forms (r2a-read-book (string-append book ".lisp")
                                           state))
                     (events (r2a-expand-events (r2a-project-events forms nil)
                                                dir (cons book seen)
                                                (1- depth) state)))
             (value (list* 'r2a-included-book book events)))))))
    ((and (eq (car event) 'local) (consp (cdr event)))
     (er-let* ((x (r2a-expand-event (cadr event) dir seen depth state)))
       (value (list* 'local x (cddr event)))))
    ((and (eq (car event) 'encapsulate) (consp (cdr event)))
     (er-let* ((xs (r2a-expand-events (cddr event) dir seen depth state)))
       (value (list* 'encapsulate (cadr event) xs))))
    (t (value event))))
 (defun r2a-expand-events (events dir seen depth state)
   (declare (xargs :stobjs state :verify-guards nil
                   :guard (and (stringp dir) (true-listp seen) (natp depth))
                   :measure (two-nats-measure depth (acl2-count events))))
   (if (atom events) (value events)
     (er-let* ((x (r2a-expand-event (car events) dir seen depth state))
               (xs (r2a-expand-events (cdr events) dir seen depth state)))
       (value (cons x xs))))))

(local (make-flag r2a-expand-event))

(local
 (defthm-flag-r2a-expand-event
   (defthm state-p1-of-r2a-expand-event
     (implies (state-p1 state)
              (state-p1 (mv-nth 2 (r2a-expand-event event dir seen depth
                                                    state))))
     :flag r2a-expand-event)
   (defthm state-p1-of-r2a-expand-events
     (implies (state-p1 state)
              (state-p1 (mv-nth 2 (r2a-expand-events events dir seen depth
                                                     state))))
     :flag r2a-expand-events)))

(verify-guards r2a-expand-event)

; The checked interface of EVENTS: projected, expanded, and checked.
(defun r2a-interface (ctx events dir state)
  (declare (xargs :stobjs state :guard (stringp dir)))
  (if (not (true-listp events))
      (r2a-fail ctx (msg "Malformed event list: ~x0" events) state)
    (er-let* ((interface (r2a-expand-events (r2a-project-events events nil)
                                            dir nil *r2a-max-include-depth*
                                            state)))
      (let ((err (r2a-interface-error interface)))
        (if err
            (r2a-fail ctx
                      (msg "Rejected retained definitions, witnesses, or ~
                            theorem: ~x0"
                           err)
                      state)
          (value interface))))))

;;; ACL2(r): prove and record an export

(defun r2a-record-export (name interface state)
  (declare (xargs :stobjs state :guard (plist-worldp (w state))))
  (cond ((not (r2a-clean-worldp state))
         (r2a-fail 'r2a-export
                   (msg "The completed source proof used trust tags, skipped ~
                         proofs, redefinition, or added axioms.")
                   state))
        ((r2a-interface-error interface)
         (r2a-fail 'r2a-export (msg "Invalid retained interface.") state))
        (t (value `(table r2a-exports ',name
                          ',(r2a-strip-proofs interface))))))

(defun r2a-export-fn (name events state)
  (declare (xargs :stobjs state
                  :guard (and (true-listp events) (plist-worldp (w state)))))
  (cond ((not (symbolp name))
         (r2a-fail 'r2a-export
                   (msg "The export name must be a symbol: ~x0" name)
                   state))
        ((not (r2a-clean-worldp state))
         (r2a-fail 'r2a-export
                   (msg "Requires ACL2(r), proofs enabled, and no trust tags, ~
                         skipped proofs, redefinition, or added axioms.")
                   state))
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

; The free variables of a term accepted by R2A-TERMP, without duplicates.
; This agrees with ALL-VARS of its translation.  If it did not, the
; generated DEFUN or DEFTHM below would fail; it cannot cause unsoundness.
; The names bound by a LET.
(defun r2a-bound-vars (bindings)
  (declare (xargs :guard t))
  (if (atom bindings) nil
    (cons (and (consp (car bindings)) (caar bindings))
          (r2a-bound-vars (cdr bindings)))))

(mutual-recursion
 (defun r2a-term-vars (x)
   (declare (xargs :guard t :verify-guards nil
                   :measure (acl2-count x)))
   (cond ((atom x)
          (and (legal-variablep x) (list x)))
         ((not (true-listp x)) nil)
         ((eq (car x) 'quote) nil)
         ((and (eq (car x) 'let) (consp (cdr x)) (consp (cddr x)))
          (union-equal (r2a-bindings-vars (cadr x))
                       (set-difference-equal (r2a-term-vars (caddr x))
                                             (r2a-bound-vars (cadr x)))))
         ((and (eq (car x) 'let*) (consp (cdr x)) (consp (cddr x)))
          (r2a-let*-vars (cadr x) (caddr x)))
         (t (r2a-terms-vars (cdr x)))))
 (defun r2a-terms-vars (xs)
   (declare (xargs :guard t :verify-guards nil
                   :measure (acl2-count xs)))
   (if (atom xs) nil
     (union-equal (r2a-term-vars (car xs)) (r2a-terms-vars (cdr xs)))))
 ; The variables of the bound expressions of a LET.
 (defun r2a-bindings-vars (bindings)
   (declare (xargs :guard t :verify-guards nil
                   :measure (acl2-count bindings)))
   (if (atom bindings) nil
     (union-equal (and (consp (car bindings)) (consp (cdar bindings))
                       (r2a-term-vars (cadar bindings)))
                  (r2a-bindings-vars (cdr bindings)))))
 (defun r2a-let*-vars (bindings body)
   (declare (xargs :guard t :verify-guards nil
                   :measure (+ 1 (acl2-count bindings) (acl2-count body))))
   (if (atom bindings) (r2a-term-vars body)
     (union-equal (and (consp (car bindings)) (consp (cdar bindings))
                       (r2a-term-vars (cadar bindings)))
                  (remove-equal (and (consp (car bindings)) (caar bindings))
                                (r2a-let*-vars (cdr bindings) body))))))

(local (make-flag r2a-term-vars))

(local
 (defthm-flag-r2a-term-vars
   (defthm true-listp-of-r2a-term-vars
     (true-listp (r2a-term-vars x))
     :flag r2a-term-vars)
   (defthm true-listp-of-r2a-terms-vars
     (true-listp (r2a-terms-vars xs))
     :flag r2a-terms-vars)
   (defthm true-listp-of-r2a-bindings-vars
     (true-listp (r2a-bindings-vars bindings))
     :flag r2a-bindings-vars)
   (defthm true-listp-of-r2a-let*-vars
     (true-listp (r2a-let*-vars bindings body))
     :flag r2a-let*-vars)))

(verify-guards r2a-term-vars)

; Every theorem gets its own predicate and exact singleton-clause processor.
; This avoids assuming that the theorem's surface syntax equals a clause.
; The wrapper and all visible interface functions are explicit supporters.
(defun r2a-import-theorem (event functions)
  (declare (xargs :guard (and (true-listp event) (<= 3 (len event))
                              (symbolp (cadr event))
                              (symbol-listp functions))))
  (let* ((name (cadr event)) (formula (caddr event))
         (pred (add-suffix name "$R2A-PRED"))
         (cp (add-suffix name "$R2A-CP"))
         (lemma (add-suffix name "$R2A-FACT"))
         (vars (r2a-term-vars formula))
         (call (cons pred vars)))
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
         :rule-classes nil))))

; Applied only to checked interfaces; other events are returned unchanged,
; so they are admitted, if at all, by ordinary proof.
(mutual-recursion
 (defun r2a-import-event (event functions)
   (declare (xargs :guard (symbol-listp functions)))
   (cond
    ((not (and (consp event) (true-listp event))) event)
    ((eq (car event) 'defthm)
     (if (and (<= 3 (len event)) (symbolp (cadr event)))
         (r2a-import-theorem event functions)
       event))
    ((and (eq (car event) 'local) (consp (cdr event)))
     (list 'local (r2a-import-event (cadr event) functions)))
    ((and (eq (car event) 'encapsulate) (consp (cdr event))
          (r2a-signaturesp (cadr event)))
     (list* 'encapsulate (cadr event)
            (r2a-import-events (cddr event)
                               (append (strip-cars (cadr event)) functions))))
    ; The sibling book is certified and included natively in ACL2.
    ((and (eq (car event) 'r2a-included-book) (consp (cdr event)))
     (list 'include-book (cadr event)))
    (t event)))
 (defun r2a-import-events (events functions)
   (declare (xargs :guard (symbol-listp functions)))
   (if (atom events) nil
     (mv-let (err fs exported) (r2a-check-event (car events) functions)
       (declare (ignore err exported))
       (cons (r2a-import-event (car events) functions)
             (r2a-import-events (cdr events) fs))))))

; The source book must consist of exactly these forms, so that no other
; event in it can affect what ACL2(r) proves.
(defun r2a-export-book-p (forms)
  (declare (xargs :guard t))
  (and (true-listp forms)
       (equal (len forms) 2)
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
    (r2a-fail 'r2a-import
              (msg "Expected a relative book name, got ~x0." book)
              state))
   ((not (equal (current-package state) "ACL2"))
    (r2a-fail 'r2a-import (msg "Import from the \"ACL2\" package.") state))
   (t
    (er-let* ((forms (r2a-read-book (string-append book ".lisp") state)))
      (if (not (r2a-export-book-p forms))
          (r2a-fail 'r2a-import
                    (msg "~x0 must contain only (in-package \"ACL2\"), ~
                          (include-book \"transfer\"), and one R2A-EXPORT ~
                          form."
                         book)
                    state)
        (let ((export (cadr forms)))
          (er-let* ((interface (r2a-interface 'r2a-import (cddr export)
                                              (r2a-directory-part book)
                                              state)))
            (value (cons (cadr export) interface)))))))))

(defun r2a-import-fn (book state)
  (declare (xargs :stobjs state))
  (if *r2a-real-build*
      (r2a-fail 'r2a-import (msg "Run the importer in ordinary ACL2.") state)
    (er-let* ((export (r2a-source-export book state)))
      (value `(progn
                ,@(r2a-import-events (cdr export) nil)
                (table r2a-exports ',(car export)
                       ',(r2a-strip-proofs (cdr export))))))))

(defmacro r2a-import (book)
  `(make-event (r2a-import-fn ,book state)))

;;; Properties of the checker
;
; These state, as theorems, the vocabulary policy described in TRANSFER.md.

; The function and macro symbols applied in a term, as R2A-TERMP sees it.
(mutual-recursion
 (defun r2a-term-fns (x)
   (declare (xargs :guard t))
   (cond ((or (atom x) (not (true-listp x)) (eq (car x) 'quote)) nil)
         ((member-eq (car x) '(let let*))
          (append (r2a-bindings-fns (cadr x)) (r2a-term-fns (caddr x))))
         (t (cons (car x) (r2a-terms-fns (cdr x))))))
 (defun r2a-terms-fns (xs)
   (declare (xargs :guard t))
   (if (atom xs) nil
     (append (r2a-term-fns (car xs)) (r2a-terms-fns (cdr xs)))))
 (defun r2a-bindings-fns (xs)
   (declare (xargs :guard t))
   (if (atom xs) nil
     (append (and (consp (car xs)) (consp (cdar xs))
                  (r2a-term-fns (cadar xs)))
             (r2a-bindings-fns (cdr xs))))))

(local (make-flag r2a-termp))

(local
 (defthm-flag-r2a-termp
   (defthm r2a-termp-fns-lemma
     (implies (r2a-termp x functions)
              (subsetp-equal (r2a-term-fns x)
                             (append *r2a-operators* functions)))
     :flag r2a-termp)
   (defthm r2a-terms-p-fns-lemma
     (implies (r2a-terms-p xs functions)
              (subsetp-equal (r2a-terms-fns xs)
                             (append *r2a-operators* functions)))
     :flag r2a-terms-p)
   (defthm r2a-bindingsp-fns-lemma
     (implies (r2a-bindingsp xs functions)
              (subsetp-equal (r2a-bindings-fns xs)
                             (append *r2a-operators* functions)))
     :flag r2a-bindingsp)))

; An accepted term applies only reviewed operators and the given functions.
(defthm r2a-termp-applies-only-vocabulary
  (implies (r2a-termp x functions)
           (subsetp-equal (r2a-term-fns x)
                          (append *r2a-operators* functions)))
  :hints (("Goal" :by r2a-termp-fns-lemma)))

; A LOCAL event never exports a function name.
(defthm r2a-local-exports-nothing
  (equal (mv-nth 2 (r2a-check-event (list 'local x) functions))
         nil))

; An encapsulate with signatures leaves the vocabulary unchanged: neither its
; constrained functions nor definitions within it become available to later
; transferred events.
(defthm r2a-nontrivial-encapsulate-keeps-vocabulary
  (implies (consp sigs)
           (and (equal (mv-nth 1 (r2a-check-event
                                  (list* 'encapsulate sigs events)
                                  functions))
                       functions)
                (equal (mv-nth 2 (r2a-check-event
                                  (list* 'encapsulate sigs events)
                                  functions))
                       nil))))
