# Basel bounds through checked ACL2(r) event transfer

This package proves rational bounds for the Basel partial sums in ordinary
ACL2, using an ACL2(r) proof and an explicit trust tag. The preparation,
interface checking, export, and import are implemented in ACL2/ACL2(r).
There is no Python step.

The transfer mechanism is **restricted and trusted**, not a verified general
importer for arbitrary ACL2(r) books. It checks every event in its portable
interface, including local definitions, local theorems, and encapsulate
witnesses. Matt Kaufmann's hidden square-root witness is a regression test.
See [TRANSFER.md](TRANSFER.md) for the exact boundary and remaining trust.

## Origin and scope

This follows Matt Kaufmann's suggestion during Ruben Gamboa's ACL2 Workshop
2026 talk, *An Alternative Proof in ACL2(r) of Euler's Solution to the Basel
Problem*. The initial implementation used a manually audited, hard-coded
theorem import. This revision replaces that mechanism with a reusable checked
event interface and replaces the Python source adapter with ACL2 code.

The mathematical results still use a fixed pi interval of width 10^-20.
They establish finite bounds and a rational Cauchy estimate. They do not
represent pi as an ordinary ACL2 number or implement an arbitrary-precision
version of the exact Basel identity.

## What changes at the boundary

In ACL2(r), an export has the form:

```lisp
(r2a-export example
  (defun rational-double (x) (* 2 (ifix x)))
  (defthm double-is-rational
    (rationalp (rational-double x))))
```

The checker first checks the entire interface. ACL2(r) then admits its
events normally, with proofs enabled. Only after both passes of the enclosing
encapsulate succeed does it record the checked interface. After successful
certification, a separate top-level command writes the receipt:

```lisp
(r2a-write-export 'example "example.r2a" state)
```

In ordinary ACL2:

```lisp
(include-book "transfer")
(r2a-import "example.r2a")
```

The importer rechecks the complete interface and admits definitions normally.
It generates a local trusted clause processor for each theorem, with explicit
supporters and tag `:acl2r-checked-transfer`. Its exact accepted clause is
derived from that theorem; it has no hard-coded Basel proposition.
The auxiliary predicates, processors, and supporting facts are local.

A receipt is data from a trusted ACL2(r) run, **not a proof certificate checked
by ordinary ACL2**. Its authenticity and the transfer implementation remain
part of the trust obligation. Do not hand-edit receipts or the export table.

## Results

Let `S_N = sum(j=1,...,N) 1/j^2`, and let

```
L = 314159265358979323846 / 100000000000000000000
U = 314159265358979323847 / 100000000000000000000
```

| Theorem | Result |
| --- | --- |
| `bq-fixed-basel-bounds` | For positive n: L^2/6 - (L^2+2)/(6*2^n) <= S_(2^n) <= U^2/6. |
| `bq-fixed-all-partial-sums-bound` | For positive N: L^2/6 - 3/N <= S_N <= U^2/6. |
| `bq-fixed-width-bound` | The dyadic enclosure width is less than 10^-19 + 2/2^n. |
| `bq-partial-sums-tail` | For 1 <= m <= n: 0 <= S_n-S_m <= 1/m-1/n. No trust tag. |
| `bq-cauchy-bound` | For rational eps > 0, m*eps >= 1 and 1 <= m <= n: abs(S_n-S_m) <= eps. No trust tag. |
| `bq-finite-enclosure-from-odd-bound` | Rational endgame parameterized by rational endpoints. No trust tag. |
| `bq-demo-2-to-80-terms` | 1.644934066848226436 <= S_(2^80) <= 1.644934066848226437. |

The transferable ACL2(r) result bounds the finite odd sum:

```
L^2 * (1/8 - 1/2^(n+3))
  <= sum(j=1,...,2^(n-1)) 1/(2*j-1)^2
  <= U^2/8.
```

All subsequent splitting, telescoping, and error propagation are ordinary
ACL2 proofs. The range-sum definitions use exclusive upper endpoints;
`bq-sum` supplies the extra 1 for an inclusive partial sum.

## Ordinary ACL2 certification

Use an ordinary ACL2 installation with certified Community Books.
The checked-in `basel.r2a` is the receipt produced by the ACL2(r) run
documented in [VALIDATION.md](VALIDATION.md). From this directory:

```sh
ACL2_ROOT=/absolute/path/to/ordinary-acl2
"$ACL2_ROOT/books/build/cert.pl" --acl2 "$ACL2_ROOT/saved_acl2" \
  transfer-tests.lisp example-import.lisp demo.lisp
```

The `.acl2` files authorize only `:acl2r-checked-transfer`. To load:

```lisp
(include-book "basel-rational" :ttags (:acl2r-checked-transfer))
```

To use only the untrusted-import-free rational lemmas:

```lisp
(include-book "rational-proofs")
```

## Reproduce the ACL2(r) proof and receipt

Use a separate checkout/copy of this package for ACL2(r) certificates.
Do not reuse ordinary ACL2 certificates in ACL2(r), or vice versa.
The upstream source revision used for validation is:

```
https://github.com/acl2/acl2
330a2344fa44d08fbd5fbf24c4b44a7473c9803d
books/nonstd/basel/
```

The ACL2(r) installation needs its certified nonstandard-analysis books.
In a fresh ACL2(r) session in the separate package directory, certify the
utilities and the upstream helper, undoing each certification event:

```lisp
(certify-book "transfer" 0)
(u)
(certify-book "transfer-tests" 0)
(u)
(certify-book "prepare-basel" 0)
(u)
(certify-book "/ABS/ACL2R/books/nonstd/basel/complex-helper" 0)
(u)

(include-book "prepare-basel")
(r2a-prepare-basel
 "/ABS/ACL2R/books/nonstd/basel/basel-series.lisp"
 "rational-defs.lisp"
 "acl2r-export-tail.lsp"
 "/ABS/ACL2R/books/nonstd/basel/complex-helper"
 "basel-source.lisp"
 state)
(ubt 1)

(certify-book "basel-source" 0)
(u)
(include-book "basel-source")
(r2a-write-export 'basel "new-basel.r2a" state)
```

Replace `/ABS/ACL2R` with the actual checkout path. The last command refuses
to overwrite an existing receipt. Compare `new-basel.r2a` with the distributed
`basel.r2a`, or copy the newly produced receipt to the ordinary ACL2 directory.

`prepare-basel.lisp` reads Lisp forms with ACL2's reader. It retains the
upstream prefix before the local `big-upper-bound` theorem, substitutes the
shared sum definitions for the integral book, and adds the checked export.
The finite lemmas are proved while still locally available. The source
adapter checks the expected cutoff and portable interface; it does not
authenticate source files by hash. Successful proof in a clean ACL2(r)
world, followed by checking the exported interface, is what matters.

For the small encapsulate example, use `(ld "example-export.lsp")` in a
fresh ACL2(r) session after certifying `transfer`, with no preexisting
`example.r2a` output file.

## Files

- `transfer.lisp`: portable-interface checker, source export, receipt I/O,
  and target event generation.
- `transfer-tests.lisp`: positive and negative boundary tests.
- `example-export.lsp`, `example-import.lisp`: rational-witness encapsulate example.
- `prepare-basel.lisp`, `acl2r-export-tail.lsp`: ACL2(r) Basel adaptation.
- `rational-defs.lisp`, `rational-proofs.lisp`: shared definitions and rational proofs.
- `trusted-bridge.lisp`, `basel-rational.lisp`, `demo.lisp`: generic import,
  finite bounds, and large-index example.
- `basel.r2a`, `example.r2a`: generated transfer receipts.
- `evidence/`: validation logs; older logs describe the initial implementation.

## Sources

- [Ruben's slides](https://www.cs.utexas.edu/~moore/acl2/workshop-2026/slides/basel-talk.pdf)
- [Pinned Basel source](https://github.com/acl2/acl2/tree/330a2344fa44d08fbd5fbf24c4b44a7473c9803d/books/nonstd/basel)
- Pi bounds: `books/nonstd/nsa/trig.lisp`, especially `m-pi`,
  `m-pi+eps`, and `pi-tight-bound`.
- [Trusted clause processors](https://acl2.org/doc/index-seo.php?xkey=ACL2____DEFINE-TRUSTED-CLAUSE-PROCESSOR)

The range sums and elementary power-of-two induction track upstream code.
New transfer and rational endgame code is MIT licensed. The source adapter
reads upstream files from the user's checkout.
