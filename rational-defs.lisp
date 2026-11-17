; Rational interface for Ruben Gamboa's Basel proof.
; New code: SPDX-License-Identifier: MIT
(in-package "ACL2")

; These two definitions agree with the upstream ACL2(r) definitions.
; Their upper endpoints are EXCLUSIVE.
(defun basel-series (i n)
  (declare (xargs :measure (nfix (- n i))))
  (if (zp (- n i))
      0
    (+ (expt i -2)
       (basel-series (1+ i) n))))

(defun basel-odds (i n)
  (declare (xargs :measure (nfix (- n i))))
  (if (zp (- n i))
      0
    (+ (expt (- (* 2 i) 1) -2)
       (basel-odds (1+ i) n))))

(defun bq-pi-lo ()
  314159265358979323846/100000000000000000000)

(defun bq-pi-hi ()
  314159265358979323847/100000000000000000000)

(defun bq-odd-enclosurep (n lo hi)
  (let ((s (basel-odds 1 (1+ (expt 2 (1- n))))))
    (and (<= (* (expt lo 2)
                (- 1/8 (/ (expt 2 (+ n 3)))))
             s)
         (<= s (* 1/8 (expt hi 2))))))

; A total, universally quantified proposition. Nonpositive/noninteger n
; deliberately impose no constraint. Used IDENTICALLY in both systems.
(defun bq-fixed-odd-enclosure (n)
  (implies (posp n)
           (bq-odd-enclosurep n (bq-pi-lo) (bq-pi-hi))))

(defun bq-sum (n)
  (basel-series 1 (1+ (nfix n))))

(defun bq-dyadic-lower (n lo)
  (- (/ (expt lo 2) 6)
     (/ (+ (expt lo 2) 2) (* 6 (expt 2 n)))))

(defun bq-dyadic-upper (hi)
  (/ (expt hi 2) 6))

(defun bq-dyadic-enclosurep (n lo hi)
  (and (<= (bq-dyadic-lower n lo) (bq-sum (expt 2 n)))
       (<= (bq-sum (expt 2 n)) (bq-dyadic-upper hi))))

(defun bq-enclosure-width (n lo hi)
  (+ (/ (- (expt hi 2) (expt lo 2)) 6)
     (/ (+ (expt lo 2) 2) (* 6 (expt 2 n)))))
