# Validation of the Basel development import

## Revalidation: SBCL 2.6.10 and ACL2 master

Both procedures in [README.md](README.md) were rerun from scratch in the
dev container in `.devcontainer/` (separate `/opt/acl2` and `/opt/acl2r`
installations), using `scripts/acl2r-reproduce.sh` and
`scripts/acl2-certify.sh`:

- SBCL 2.6.10, built from the `sbcl-2.6.10` source tag.
- ACL2 `master` at `043ce2f2e51aa3dd7fde519be0b1091d7bc4077a` for both
  ordinary ACL2 and ACL2(r). The startup banner reports a development
  snapshot based on ACL2 Version 8.7; `acl2-version` is still
  `ACL2 Version 8.7(r)` in ACL2(r).
- For ACL2(r) only, `books/nonstd` from
  `330a2344fa44d08fbd5fbf24c4b44a7473c9803d` (`acl2r-context`), because the
  Basel books are not on master. The three upstream Basel files match the
  hashes in `evidence/source-manifest.json`.

Results:

- ACL2(r): `transfer`, `transfer-tests`, `development-tests`,
  `prepare-basel`, and `complex-helper` certified. `basel-analytic` certified
  in 54.68 seconds with 688,176 prover steps, and `basel-source` in 0.82
  seconds with 502 prover steps, matching the step counts below.
  `new-basel.r2a` was byte-for-byte identical to `basel.r2a`.
- ACL2(r): the example export reproduced `example.r2a` byte-for-byte.
  `development-source-tests.lsp` ended with
  `:DEVELOPMENT-SOURCE-TESTS-PASSED` and `export-failure-tests.lsp` with
  `:ALL-EXPECTED-EXPORT-FAILURES-CHECKED`.
- Ordinary ACL2: the README `cert.pl` command certified all client books
  (`demo` 63 and `basel-interval` 1,478 prover steps). `transfer` and
  `rational-proofs` were included with `:ttags nil`. The width of
  `bq-basel-interval` at N=10^20 equals the value given below.
- In the same container, ordinary ACL2 also imported the regenerated
  `build/acl2r/new-basel.r2a` and certified every client book. Each script
  refused to run with the other flavor's executable, and ordinary ACL2's
  `include-book` rejected an ACL2(r)-certified `transfer` ("We do not permit
  ACL2 books to be processed by ACL2(r) or vice versa").

Corrections found by this run, now reflected in README.md:

1. `books/nonstd/basel/` exists only on the `acl2r-context` branch, not on
   master; `basel-series.lisp` also needs branch-only nonstd books.
2. The README `cert.pl` command failed with `No rule to make target
   'unchecked.lisp'`: `cert.pl` treated quoted `include-book` test data in
   `transfer-tests.lisp` (and `development-tests.lisp`) as dependencies. The
   data forms are now split across lines; their meaning is unchanged.
3. Interactive ACL2(r) certification needs the nonstd dependency books
   certified first; the README now lists them.

Logs: `evidence/master-sbcl-2.6.10/`.

## Original validation

This revision was validated with ACL2 8.7 and ACL2 8.7(r), built on SBCL 2.5.2.
The source checkout was commit `330a2344fa44d08fbd5fbf24c4b44a7473c9803d`.
Source and target used separate certificate directories.

### Clarified local-event policy

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

### Ordinary ACL2 client

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

### Source execution regressions

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

- `evidence/master-sbcl-2.6.10/`: the SBCL 2.6.10 / ACL2 master revalidation.
- `evidence/basel-development-acl2r.log`: successful source certification summaries.
- `evidence/basel-development-acl2.log`: successful target certification summaries.
- `evidence/development-source-tests.log`: full expected-error regression log.

The last three files listed are from the original validation of this revision.
Other evidence files describe earlier versions and are retained as history.
Summary excerpts are not proof certificates. Build products are not committed;
rebuild them using the matching ACL2 executable and certified system books.

This verifies the admitted theorems and tested checking behavior. It does
not prove the transfer algorithm's soundness or authenticate receipt
provenance. Those remain explicit trust obligations, described in
[TRANSFER.md](TRANSFER.md). The result uses a fixed rational pi enclosure;
arbitrary-precision pi bounds and an exact rational-sequence formulation of
the Basel identity are not implemented.
