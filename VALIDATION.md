# Validation of the ACL2-native transfer

Validated with ACL2 8.7 and ACL2 8.7(r), both built on SBCL 2.5.2.
The source checkout was commit
`330a2344fa44d08fbd5fbf24c4b44a7473c9803d`.
Source and target used separate certificate directories.

## Ordinary ACL2

These books certified successfully:

- `transfer.lisp` and `transfer-tests.lisp`, without trust tags.
- `rational-defs.lisp` and `rational-proofs.lisp`, without trust tags.
- `trusted-bridge.lisp`, `basel-rational.lisp`, and `demo.lisp`, allowing
  only `:acl2r-checked-transfer`.
- `example-import.lisp`, allowing only that tag. This exercises a nonempty
  encapsulate, a rational local witness, a local helper and theorem, and an
  ordinary ACL2 consequence of the exported constraint.

The final large-index example again used 63 prover steps. No enormous
partial sum was evaluated.

## ACL2(r)

These books certified successfully without trust tags:

- `transfer.lisp`
- `transfer-tests.lisp`
- `prepare-basel.lisp`
- the ACL2-generated `basel-source.lisp`

The generated source book took approximately 74 seconds and 688,176 prover
steps in the final run. It includes the original finite analytic argument
and proves `bq-fixed-odd-enclosure-export`. The receipt was written after
successful source certification and inclusion.

The small example also completed its source proofs and exported its receipt.
The receipts from the final source run were byte-for-byte identical to those
used for ordinary ACL2 certification.

## Rejection tests

`transfer-tests.lisp` certified in both systems. It covers:

- Matt's local square-root witness, with both `sqrt` and `acl2-sqrt`.
- A nested local encapsulate containing that witness.
- A nonportable local theorem.
- Unsupported macros, named constants, event generation, skipped proofs,
  includes, and nonstandard definitions.
- A signature without a direct local witness.
- Local-name leakage after an encapsulate.
- The invalid transfer of a later theorem about an already abstract function.

`export-failure-tests.lsp` was run in ACL2(r). Its three expected failures
were followed by successful assertions that no export was recorded:
the rejected irrational witness, a false source theorem, and a source event
that succeeds in the first pass but fails local-compatibility checking in
the second. The log ends with
`:ALL-EXPECTED-EXPORT-FAILURES-CHECKED`.

## Evidence and interpretation

- `evidence/native-acl2-summary.log`: ordinary certification summaries.
- `evidence/native-acl2r-summary.log`: source certification and export summaries.
- `evidence/native-export-failures.log`: full expected-failure regression log.

The summary files are excerpts, not proof certificates. Existing older
`*.cert.out` files and `source-manifest.json` in `evidence/` describe the
previous hard-coded bridge and Python adapter; they are historical evidence.

This validation establishes successful admission and the tested rejection
behavior. It does not verify the transfer algorithm's soundness or
authenticate receipt provenance. Those remain explicit trust obligations;
see [TRANSFER.md](TRANSFER.md). The source syntax and abstraction restrictions
are intentional, and the mathematical result remains fixed precision.

Build products (`.cert`, `.fasl`, `.port`) are not committed. Rebuild them
with the matching ACL2 executable. The import books include `depends-on`
comments so `cert.pl` tracks receipt changes.
