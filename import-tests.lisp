; Ordinary ACL2 tests of R2A-IMPORT and the imported Basel results.
; SPDX-License-Identifier: MIT
; cert_param: (non-acl2r)
(in-package "ACL2")
(include-book "std/testing/must-fail" :dir :system)

; The checker and the portable rational development use no trust tags.
(include-book "transfer" :ttags nil)
(include-book "rational-proofs" :ttags nil)

; Trust tag :ACL2R-CHECKED-TRANSFER is allowed by import-tests.acl2.
(include-book "basel-interval")
(include-book "demo")
(include-book "example-import")

(assert-event
 (let ((iv (bq-basel-interval 100000000000000000000)))
   (equal (- (cdr iv) (car iv))
          809439510239319549231/20000000000000000000000000000000000000000)))

; The importer re-derives and re-checks the interface itself; it does not
; rely on ACL2(r) having rejected these sources.
(must-fail (r2a-import "import-fixtures/reader-conditional"))
(must-fail (r2a-import "import-fixtures/extra-event"))
(must-fail (r2a-import "import-fixtures/witness"))
(must-fail (r2a-import "import-fixtures/includes-nonportable"))
; Not an export book at all.
(must-fail (r2a-import "import-fixtures/nonportable"))
