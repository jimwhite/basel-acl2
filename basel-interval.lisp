; Executable rational enclosure API for the Basel example.
; No summation is performed by bq-basel-interval.
(in-package "ACL2")
(include-book "basel-rational" :ttags (:acl2r-checked-transfer))
(local (include-book "arithmetic-5/top" :dir :system))

(defun bq-basel-interval (n)
  (let ((index (if (posp n) n 1)))
    (cons (- (/ (expt (bq-pi-lo) 2) 6) (/ 3 index))
          (/ (expt (bq-pi-hi) 2) 6))))

(defun bq-basel-interval-width (n)
  (- (cdr (bq-basel-interval n)) (car (bq-basel-interval n))))

(defthm bq-basel-interval-is-rational
  (and (rationalp (car (bq-basel-interval n)))
       (rationalp (cdr (bq-basel-interval n)))))

(defthm bq-basel-interval-encloses-partial-sum
  (implies (posp n)
           (and (<= (car (bq-basel-interval n)) (bq-sum n))
                (<= (bq-sum n) (cdr (bq-basel-interval n)))))
  :hints (("Goal" :use bq-fixed-all-partial-sums-bound
           :in-theory (disable bq-sum bq-fixed-dyadic-enclosure
                               bq-finite-enclosure-from-odd-bound
                               bq-split-odds-evens)))
  :rule-classes nil)

(defthm bq-basel-interval-width-exact
  (implies (posp n)
           (equal (bq-basel-interval-width n)
                  (+ (/ (- (expt (bq-pi-hi) 2) (expt (bq-pi-lo) 2)) 6)
                     (/ 3 n)))))

; A uniform numerical result for every N >= 10^20, proved symbolically.
(defthm bq-basel-decimal-enclosure
  (implies (and (integerp n) (<= 100000000000000000000 n))
           (and (<= 1644934066848226436/1000000000000000000 (bq-sum n))
                (<= (bq-sum n) 1644934066848226437/1000000000000000000)))
  :hints (("Goal" :use bq-fixed-all-partial-sums-bound
           :in-theory (disable bq-sum bq-basel-interval
                               bq-fixed-dyadic-enclosure
                               bq-finite-enclosure-from-odd-bound
                               bq-split-odds-evens)
           :nonlinearp t))
  :rule-classes nil)

(defthm bq-basel-interval-width-at-10-to-20
  (implies (and (integerp n) (<= 100000000000000000000 n))
           (< (bq-basel-interval-width n) 1/10000000000000000000))
  :hints (("Goal" :nonlinearp t))
  :rule-classes nil)
