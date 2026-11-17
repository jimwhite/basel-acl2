; Appended to the original basel-series.lisp by prepare-acl2r.py.
; At this point its LOCAL finite lemmas remain available to certification.
; There is no trust tag here: this theorem must be PROVED in ACL2(r).

(defthm bq-fixed-odd-enclosure-export
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
