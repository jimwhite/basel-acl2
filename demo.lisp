; Demonstrate an enormous finite sum without evaluating its summands.
; SPDX-License-Identifier: MIT
; cert_param: (non-acl2r)
(in-package "ACL2")
(include-book "basel-rational" :ttags ((:acl2r-checked-transfer)))

(defthm bq-demo-2-to-80-terms
  (and (<= 1644934066848226436/1000000000000000000
           (bq-sum (expt 2 80)))
       (<= (bq-sum (expt 2 80))
           1644934066848226437/1000000000000000000))
  :hints (("Goal"
           :use ((:instance bq-fixed-basel-bounds (n 80)))
           :in-theory '(bq-pi-lo bq-pi-hi
                        (:e posp) (:e expt) (:e binary-*) (:e binary-+)
                        (:e unary-/) (:e unary--) (:e <) (:e equal) (:e not))))
  :rule-classes nil)
