; Ordinary ACL2 import of the ACL2(r) Basel export.
; SPDX-License-Identifier: MIT
; cert_param: (non-acl2r)
(in-package "ACL2")
; (depends-on "basel-export.lisp")
(include-book "rational-defs")
(include-book "transfer")

; Read basel-export.lisp, which ACL2(r) certifies, and check and admit its
; portable interface: rational-defs is included natively, and the theorem
; BQ-FIXED-ODD-ENCLOSURE-EXPORT is admitted under the trust tag
; :ACL2R-CHECKED-TRANSFER.  The ACL2(r) proof is not rechecked here.
(r2a-import "basel-export")
