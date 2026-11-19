; ACL2-native source adapter. No Python, raw Lisp, or shell execution.
; This book is used only in the ACL2(r) build directory.
(in-package "ACL2")
(include-book "transfer")
(program)
(set-state-ok t)

(defun r2a-read-forms (channel state)
  (declare (xargs :stobjs state))
  (mv-let (eof object state) (read-object channel state)
    (if eof (mv nil state)
      (mv-let (rest state) (r2a-read-forms channel state)
        (mv (cons object rest) state)))))

(defun r2a-read-file (path state)
  (declare (xargs :stobjs state))
  (mv-let (channel state) (open-input-channel path :object state)
    (if (not channel) (er soft 'r2a-prepare "Cannot read ~x0." path)
      (mv-let (forms state) (r2a-read-forms channel state)
        (let ((state (close-input-channel channel state)))
          (value forms))))))

(defun r2a-basel-prefix (forms helper)
  (cond
   ((endp forms) (mv :missing-finite-bound-cutoff nil))
   ((and (eq (caar forms) 'local)
         (eq (caadar forms) 'defthmd)
         (eq (cadadr (car forms)) 'big-upper-bound))
    (mv nil nil))
   (t
    (mv-let (err rest) (r2a-basel-prefix (cdr forms) helper)
      (let ((event (car forms)))
        (mv err
            (cond ((or (eq (car event) 'in-package)
                       (equal event '(include-book "basel-bound"))) rest)
                  ((equal event '(local (include-book "complex-helper")))
                   (cons `(local (include-book ,helper)) rest))
                  (t (cons event rest)))))))))

(defun r2a-write-forms (forms channel state)
  (declare (xargs :stobjs state))
  (if (endp forms) state
    (let ((state (print-object$ (car forms) channel state)))
      (r2a-write-forms (cdr forms) channel state))))

(defun r2a-prepare-basel (upstream defs tail helper output state)
  (declare (xargs :stobjs state))
  (er-let* ((source (r2a-read-file upstream state))
            (definitions (r2a-read-file defs state))
            (theorems (r2a-read-file tail state)))
    (mv-let (err prefix) (r2a-basel-prefix source helper)
      (let* ((interface (append (cdr definitions) theorems))
             (bad (r2a-interface-error interface)))
        (cond
         ((not (equal (car definitions) '(in-package "ACL2")))
          (er soft 'r2a-prepare "Unexpected definitions book package."))
         (err (er soft 'r2a-prepare "Unexpected upstream structure: ~x0" err))
         (bad (er soft 'r2a-prepare "Nonportable interface: ~x0" bad))
         (t
          (mv-let (channel state) (open-output-channel output :character state)
            (if (not channel) (er soft 'r2a-prepare "Cannot write ~x0." output)
              (let* ((forms
                      (append (list '(in-package "ACL2")
                                    '(include-book "transfer"))
                              (cdr definitions) prefix
                              (list `(r2a-export basel ,@interface))))
                     (state (r2a-write-forms forms channel state))
                     (state (close-output-channel channel state)))
                (value :prepared))))))))))

; Prepare two books. The first proves the rationalization in ACL2(r).
; The second contains the actual development sent through the checked bridge:
; rational definitions, a LOCAL analytic proof book, and a rational theorem.
(defun r2a-write-book (book forms state)
  (declare (xargs :stobjs state))
  (mv-let (channel state)
    (open-output-channel (concatenate 'string book ".lisp") :character state)
    (if (not channel) (er soft 'r2a-prepare "Cannot write book ~x0." book)
      (let* ((state (r2a-write-forms forms channel state))
             (state (close-output-channel channel state)))
        (value book)))))

(defun r2a-prepare-basel-development
  (upstream defs tail helper analytic-book transfer-book state)
  (declare (xargs :stobjs state))
  (er-let* ((source (r2a-read-file upstream state))
            (definitions (r2a-read-file defs state))
            (theorems (r2a-read-file tail state)))
    (mv-let (err prefix) (r2a-basel-prefix source helper)
      (let* ((theorem (car theorems))
             (analytic-name 'bq-analytic-odd-enclosure)
             (interface-theorem
              `(defthm ,(cadr theorem) ,(caddr theorem)
                 :hints (("Goal" :by ,analytic-name)) :rule-classes nil))
             (events (append (cdr definitions)
                             (list `(local (include-book ,analytic-book))
                                   interface-theorem)))
             (bad (r2a-interface-error (r2a-project-events events nil))))
        (cond
         ((not (and (equal (car definitions) '(in-package "ACL2"))
                    (equal (len theorems) 1) (eq (car theorem) 'defthm)))
          (er soft 'r2a-prepare "Unexpected definitions or export theorem."))
         (err (er soft 'r2a-prepare "Unexpected source cutoff: ~x0" err))
         (bad (er soft 'r2a-prepare "Nonportable retained interface: ~x0" bad))
         (t
          (er-let*
              ((written-analytic
                (r2a-write-book
                 analytic-book
                 (append definitions prefix
                         (list (list* 'defthm analytic-name (cddr theorem))))
                 state))
               (written-transfer
                (r2a-write-book
                 transfer-book
                 (list '(in-package "ACL2") '(include-book "transfer")
                       (cons 'r2a-export-development (cons 'basel events)))
                 state)))
            (value (list written-analytic written-transfer)))))))))
(logic)
