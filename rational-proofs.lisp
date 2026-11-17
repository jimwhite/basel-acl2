; No trust tags, skip-proofs, defaxiom, or analytic functions in this book.
; SPDX-License-Identifier: MIT
(in-package "ACL2")
(include-book "rational-defs")
(local (include-book "arithmetic-5/top" :dir :system))

(defthm bq-series-rational
  (implies (and (integerp i) (integerp n))
           (rationalp (basel-series i n)))
  :rule-classes (:rewrite :type-prescription))

(defthm bq-odds-rational
  (implies (and (integerp i) (integerp n))
           (rationalp (basel-odds i n)))
  :rule-classes (:rewrite :type-prescription))

(defthm bq-series-nonnegative
  (implies (and (posp i) (integerp n))
           (<= 0 (basel-series i n)))
  :rule-classes :linear)

(defthm bq-series-split
  (implies (and (posp i) (integerp m) (integerp n)
                (<= i m) (<= m n))
           (equal (basel-series i n)
                  (+ (basel-series i m) (basel-series m n))))
  :hints (("Goal" :induct (basel-series i m)))
  :rule-classes nil)

; Telescoping replaces the integration in basel-bound.lisp.
(defthm bq-reciprocal-square-step
  (implies (and (integerp i) (< 1 i))
           (<= (expt i -2) (- (/ (1- i)) (/ i))))
  :hints (("Goal" :nonlinearp t))
  :rule-classes nil)

(defthm bq-series-tail-upper
  (implies (and (integerp i) (integerp n)
                (< 1 i) (<= i n))
           (<= (basel-series i n)
               (- (/ (1- i)) (/ (1- n)))))
  :hints (("Goal" :induct (basel-series i n))
          ("Subgoal *1/2" :use bq-reciprocal-square-step :nonlinearp t))
  :rule-classes nil)

; S_(2m) = O_m + S_m/4, including both endpoints correctly.
(defthm bq-split-odds-evens-range
  (implies (and (posp i) (integerp n))
           (equal (basel-series (1- (* 2 i)) (1- (* 2 n)))
                  (+ (basel-odds i n) (* 1/4 (basel-series i n)))))
  :hints (("Goal" :induct (basel-odds i n)
           :expand ((basel-series (+ -1 (* 2 i)) (+ -1 (* 2 n)))
                    (basel-series (* 2 i) (+ -1 (* 2 n)))))))

(defthm bq-split-odds-evens
  (implies (posp m)
           (equal (bq-sum (* 2 m))
                  (+ (basel-odds 1 (1+ m)) (* 1/4 (bq-sum m)))))
  :hints (("Goal" :use ((:instance bq-split-odds-evens-range
                                  (i 1) (n (1+ m))))
           :in-theory (disable bq-split-odds-evens-range basel-series basel-odds))))

(defthm bq-doubled-tail
  (implies (posp m)
           (and (<= 0 (- (bq-sum (* 2 m)) (bq-sum m)))
                (<= (- (bq-sum (* 2 m)) (bq-sum m)) (/ (* 2 m)))))
  :hints (("Goal"
           :use ((:instance bq-series-split (i 1) (m (1+ m)) (n (1+ (* 2 m))))
                 (:instance bq-series-tail-upper (i (1+ m)) (n (1+ (* 2 m))))
                 (:instance bq-series-nonnegative (i (1+ m)) (n (1+ (* 2 m)))))
           :in-theory (disable basel-series bq-series-nonnegative bq-split-odds-evens)))
  :rule-classes nil)

(defthm bq-finite-enclosure-from-odd-bound
  (implies (and (posp n) (rationalp lo) (rationalp hi)
                (bq-odd-enclosurep n lo hi))
           (bq-dyadic-enclosurep n lo hi))
  :hints (("Goal"
           :use ((:instance bq-split-odds-evens (m (expt 2 (1- n))))
                 (:instance bq-doubled-tail (m (expt 2 (1- n)))))
           :in-theory (disable basel-series basel-odds bq-split-odds-evens)
           :nonlinearp t)))

(defthm bq-enclosure-width-correct
  (implies (and (posp n) (rationalp lo) (rationalp hi))
           (equal (- (bq-dyadic-upper hi) (bq-dyadic-lower n lo))
                  (bq-enclosure-width n lo hi))))

; A constructive Cauchy bound, independently proved in ordinary ACL2.
(defthm bq-partial-sums-tail
  (implies (and (posp m) (integerp n) (<= m n))
           (and (<= 0 (- (bq-sum n) (bq-sum m)))
                (<= (- (bq-sum n) (bq-sum m)) (- (/ m) (/ n)))))
  :hints (("Goal"
           :use ((:instance bq-series-split (i 1) (m (1+ m)) (n (1+ n)))
                 (:instance bq-series-tail-upper (i (1+ m)) (n (1+ n)))
                 (:instance bq-series-nonnegative (i (1+ m)) (n (1+ n))))
           :in-theory (disable basel-series bq-series-nonnegative bq-split-odds-evens)))
  :rule-classes nil)

(defthm bq-cauchy-bound
  (implies (and (posp m) (integerp n) (<= m n)
                (rationalp eps) (< 0 eps) (<= 1 (* m eps)))
           (<= (abs (- (bq-sum n) (bq-sum m))) eps))
  :hints (("Goal" :use bq-partial-sums-tail
           :in-theory (disable bq-sum bq-split-odds-evens)
           :nonlinearp t))
  :rule-classes nil)

(defthm bq-positive-integer-below-power-of-two
  (implies (natp n) (<= n (expt 2 n)))
  ; Same elementary induction used in the upstream Basel book.
  :instructions ((:in-theory (enable expt))
                 (:induct (expt 2 n))
                 :bash
                 :pro (:casesplit (not (natp (+ n -1))))
                 (:claim (= n 0))
                 :s (:forwardchain 4)
                 (:dv 2)
                 :x (:= (* 2 (expt 2 (+ n -1))))
                 (:claim (<= n (+ 1 (expt 2 (+ n -1)))))
                 (:claim (<= 1 (expt 2 (+ n -1))))
                 (:= (+ (expt 2 (+ n -1)) (expt 2 (+ n -1))))
                 (:claim (natp (expt 2 (+ n -1))))
                 :top
                 (:generalize ((expt 2 (+ n -1)) |2^n-1|))
                 :bash :bash :bash)
  :rule-classes :linear)
