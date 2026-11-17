# Validation record

Date: 2026-11-17 (America/Los_Angeles).

Runtime: SBCL 2.5.2.debian on Linux. Ordinary ACL2 and ACL2(r) were built
separately from ACL2 commit
`330a2344fa44d08fbd5fbf24c4b44a7473c9803d` (`acl2r-context`).

## Ordinary ACL2

The following books certified successfully:

- `rational-defs.lisp`
- `rational-proofs.lisp`
- `trusted-bridge.lisp`, with exactly `:basel-acl2r-finite-bounds` permitted
- `basel-rational.lisp`, with the same tag
- `demo.lisp`, with the same tag

The proof of the demonstration with 2^80 summands counted 63 prover steps.
It instantiates the proved bound and evaluates only the rational endpoints;
it does not enumerate the sum.

The ordinary rational proof book has no trust tag. Certification of the
bridge and the books depending on it is explicitly relative to the named
trust obligation; ordinary ACL2 does not verify the ACL2(r) certificate.

## ACL2(r)

The generated `acl2r-export.lisp` certified successfully with no trust tags.
Its final theorem is exactly `(bq-fixed-odd-enclosure n)`.

The whole finite exporter replay took 61.87 seconds and 687,674 prover steps.
The newly added export theorem itself took 0.29 seconds and 19,715 prover
steps. It used `big-lower-bound-lemma-specialized-3`,
`big-upper-bound-lemma-specialized-6`, and `pi-tight-bound`.

This validates the reduced dependency chain: the original integral-based
`basel-bound` book and the final nonstandard limit argument are not needed
to prove the exported finite theorem.

## Additional checks

- Trusted processor's negative recognition assertions passed as part of
  `trusted-bridge.lisp` certification.
- The preparation script rejected a modified upstream Basel source.
- The preparation script refused to overwrite a nonempty output directory.
- The shared rational definitions in both workspaces were byte-for-byte
  identical.

## Reproduction and evidence

See `README.md` for exact commands and source references. Final successful
certification logs are included under `evidence/`. Certificate files and
compiled Lisp are intentionally not distributed: recertify with your own
matching ACL2 build and dependency tree.
