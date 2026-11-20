; ACL2(r) analytic proof of the rational odd-sum enclosure.
; SPDX-License-Identifier: MIT
; cert_param: (uses-acl2r)
(in-package "ACL2")

; The finite bounds come from Ruben Gamboa's nonstd/basel/basel-series book,
; where the needed lemmas are LOCAL.  Rather than copy that proof, the
; MAKE-EVENT below reads the upstream source when this book is certified and
; admits its events up to the first theorem that is not needed here.  The
; expansion is recorded in this book's certificate.
; (depends-on "nonstd/basel/basel-series.lisp" :dir :system)

(include-book "rational-defs")
(local (include-book "transfer")) ; only to read upstream during expansion

; The upstream header, stated here so that cert.pl sees the dependencies.
; Upstream's (include-book "basel-bound") is omitted: the events used below
; do not need it, and rational-defs defines BASEL-SERIES identically.
(local (include-book "arithmetic-5/top" :dir :system))
(include-book "nonstd/nsa/exp" :dir :system)
(include-book "nonstd/nsa/norm" :dir :system)
(include-book "nonstd/nsa/trig" :dir :system)
(include-book "nonstd/nsa/complex-polar" :dir :system)
(include-book "nonstd/nsa/raise" :dir :system)
(include-book "nonstd/nsa/standard-close-utils" :dir :system)
(local (include-book "nonstd/basel/complex-helper" :dir :system))

(local
 (defconst *bq-upstream-header*
  '((local (include-book "arithmetic-5/top" :dir :system))
    (include-book "nonstd/nsa/exp" :dir :system)
    (include-book "nonstd/nsa/norm" :dir :system)
    (include-book "nonstd/nsa/trig" :dir :system)
    (include-book "nonstd/nsa/complex-polar" :dir :system)
    (include-book "nonstd/nsa/raise" :dir :system)
    (include-book "nonstd/nsa/standard-close-utils" :dir :system)
    ; Line breaks keep cert.pl from reading these upstream-relative names.
    (include-book
     "basel-bound")
    (local (include-book
            "complex-helper")))))

; Events of FORMS before upstream's (local (defthmd big-upper-bound ...)).
(local
 (defun bq-upstream-prefix (forms)
   (declare (xargs :guard t))
   (cond ((atom forms) :missing-cutoff)
         ((and (consp (car forms))
               (eq (car (car forms)) 'local)
               (consp (cdr (car forms)))
               (consp (cadr (car forms)))
               (eq (car (cadr (car forms))) 'defthmd)
               (consp (cdr (cadr (car forms))))
               (eq (cadr (cadr (car forms))) 'big-upper-bound))
          nil)
         (t (let ((rest (bq-upstream-prefix (cdr forms))))
              (if (eq rest :missing-cutoff) rest
                (cons (car forms) rest)))))))

; Fail closed if upstream changes shape.
(local
 (defun bq-upstream-events (state)
   (declare (xargs :stobjs state
                   :guard (plist-worldp (w state))
                   :guard-hints (("Goal" :in-theory
                                  (disable r2a-read-book)))))
   (let ((dir (project-dir-lookup :system (project-dir-alist (w state)) nil)))
     (if (not (stringp dir))
         (r2a-fail 'bq-upstream-events (msg "No :system book directory.")
                   state)
       (er-let* ((forms (r2a-read-book
                         (string-append dir "nonstd/basel/basel-series.lisp")
                         state)))
         (let* ((n (len *bq-upstream-header*))
                (prefix (bq-upstream-prefix (nthcdr n (true-list-fix forms)))))
           (cond ((not (and (true-listp forms)
                            (equal (take n forms) *bq-upstream-header*)))
                  (r2a-fail 'bq-upstream-events
                            (msg "Unexpected upstream header.") state))
                 ((eq prefix :missing-cutoff)
                  (r2a-fail 'bq-upstream-events
                            (msg "Missing upstream cutoff.") state))
                 (t (value (cons 'progn prefix))))))))))

(make-event (bq-upstream-events state))

(defthm bq-analytic-odd-enclosure
  (bq-fixed-odd-enclosure n)
  :hints (("Goal"
           :use ((:instance big-lower-bound-lemma-specialized-3)
                 (:instance big-upper-bound-lemma-specialized-6)
                 (:instance pi-tight-bound))
           :in-theory (e/d (bq-fixed-odd-enclosure bq-odd-enclosurep
                            bq-pi-lo bq-pi-hi m-pi m-pi+eps)
                           (basel-odds acl2-pi (acl2-pi)))
           :nonlinearp t))
  :rule-classes nil)
