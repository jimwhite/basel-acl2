; Fixed-precision rational consequence of the ACL2(r) Basel proof.
; SPDX-License-Identifier: MIT
(in-package "ACL2")
(include-book "rational-proofs")
(local (include-book "arithmetic-5/top" :dir :system))
(include-book "trusted-bridge" :ttags (:basel-acl2r-finite-bounds))

(defthm bq-fixed-dyadic-enclosure
  (implies (posp n)
           (bq-dyadic-enclosurep n (bq-pi-lo) (bq-pi-hi)))
  :hints (("Goal"
           :use ((:instance bq-imported-odd-enclosure)
                 (:instance bq-finite-enclosure-from-odd-bound
                            (lo (bq-pi-lo)) (hi (bq-pi-hi))))
           :in-theory '(bq-fixed-odd-enclosure bq-pi-lo bq-pi-hi))))

; Explicit, easily reusable version: sum j=1,...,2^n of 1/j^2.
(defthm bq-fixed-basel-bounds
  (implies (posp n)
           (and
            (<= (- (/ (expt (bq-pi-lo) 2) 6)
                   (/ (+ (expt (bq-pi-lo) 2) 2) (* 6 (expt 2 n))))
                (bq-sum (expt 2 n)))
            (<= (bq-sum (expt 2 n)) (/ (expt (bq-pi-hi) 2) 6))))
  :hints (("Goal" :use bq-fixed-dyadic-enclosure
           :in-theory '(bq-dyadic-enclosurep bq-dyadic-lower bq-dyadic-upper)))
  :rule-classes nil)

; The width consists of a fixed pi-enclosure error and a vanishing tail.
(defthm bq-fixed-width-bound
  (implies (posp n)
           (< (bq-enclosure-width n (bq-pi-lo) (bq-pi-hi))
              (+ 1/10000000000000000000 (/ 2 (expt 2 n)))))
  :hints (("Goal" :nonlinearp t))
  :rule-classes nil)

; A simple bound for EVERY positive partial-sum index, not just powers of 2.
; The constant 3 is intentionally loose; no search for a dyadic index is
; needed because 2^n >= n. No sum with 2^n terms is evaluated in this proof.
(defthm bq-fixed-all-partial-sums-bound
  (implies (posp n)
           (and (<= (- (/ (expt (bq-pi-lo) 2) 6) (/ 3 n))
                    (bq-sum n))
                (<= (bq-sum n) (/ (expt (bq-pi-hi) 2) 6))))
  :hints (("Goal"
           :use ((:instance bq-fixed-basel-bounds)
                 (:instance bq-partial-sums-tail (m n) (n (expt 2 n))))
           :in-theory (disable bq-sum bq-fixed-dyadic-enclosure
                               bq-finite-enclosure-from-odd-bound
                               bq-split-odds-evens)
           :nonlinearp t))
  :rule-classes nil)
