# Validation of the Basel development import

This revision was validated with ACL2 8.7 and ACL2 8.7(r), built on SBCL 2.5.2.
The source checkout was commit `330a2344fa44d08fbd5fbf24c4b44a7473c9803d`.
Source and target used separate certificate directories.

## Clarified local-event policy

The following certified in both systems without trust tags:
`transfer.lisp`, `transfer-tests.lisp`, and `development-tests.lisp`.
The new tests verify that proof-only analytic locals are omitted, witnesses
inside nontrivial encapsulates are retained, nested scopes do not hide unsafe
definitions, and names from omitted helpers cannot enter exported definitions.
Retained `defchoose` events remain unsupported.

`prepare-basel.lisp` certified in ACL2(r). Its new
`r2a-prepare-basel-development` function generated two books:

- `basel-analytic.lisp` certified without trust tags in 74.77 seconds,
  using 688,176 prover steps. It proves the rational odd-sum bound using the
  original finite analytic proof and the existing rational pi enclosure.
- `basel-source.lisp` certified without trust tags in 1.19 seconds,
  using 502 prover steps. It locally includes the analytic book inside
  `r2a-export-development` and exports the rational interface.

The receipt was written only after successful source certification and
inclusion. It was byte-for-byte identical to the earlier `basel.r2a`.
The mathematical interface has not changed; the new code enforces which
local source events can be omitted.

## Ordinary ACL2 client

These books certified, allowing only `:acl2r-checked-transfer`:

- `trusted-bridge.lisp`
- `basel-rational.lisp`
- `demo.lisp` (63 prover steps for the large-index demonstration)
- `basel-interval.lisp` (1,478 prover steps)
- `example-import.lisp`

The unchanged `rational-defs.lisp` and `rational-proofs.lisp` retain their
earlier certification without trust tags.

The new interval book proves rational endpoint types, enclosure of every
positive partial sum, the exact width formula, and the following uniform
numerical result for every integer N >= 10^20:

```
1.644934066848226436 <= S_N <= 1.644934066848226437.
```

The executable `bq-basel-interval` was loaded and evaluated in ordinary ACL2
at N=10^20. It returns exact rational endpoints without evaluating S_N.
Its width at that index is exactly

```
809439510239319549231 / 20000000000000000000000000000000000000000,
```

which is less than 10^-19.

## Source execution regressions

`development-source-tests.lsp` completed with
`:DEVELOPMENT-SOURCE-TESTS-PASSED`. It verified:

- A successful development can use a local irrational square-root helper.
  Its recorded interface contains only the rational definitions and theorem.
- A false local source theorem is actually attempted and rejected, even
  though that local event would be omitted from the exported interface.
- Matt's hidden irrational witness is rejected.
- The real-valued `defchoose` counterexample is rejected.
- A skipped local proof is detected by the AFTER-proof trust-state check,
  and no export is recorded.

The older source export and expected-failure tests were also rerun.
The example receipt remained byte-for-byte identical, and the failure tests
ended with `:ALL-EXPECTED-EXPORT-FAILURES-CHECKED`.

## Evidence and limits

- `evidence/basel-development-acl2r.log`: successful source certification summaries.
- `evidence/basel-development-acl2.log`: successful target certification summaries.
- `evidence/development-source-tests.log`: full expected-error regression log.

Other evidence files describe earlier versions and are retained as history.
Summary excerpts are not proof certificates. Build products are not committed;
rebuild them using the matching ACL2 executable and certified system books.

This verifies the admitted theorems and tested checking behavior. It does
not prove the transfer algorithm's soundness or authenticate receipt
provenance. Those remain explicit trust obligations, described in
[TRANSFER.md](TRANSFER.md). The result uses a fixed rational pi enclosure;
arbitrary-precision pi bounds and an exact rational-sequence formulation of
the Basel identity are not implemented.
