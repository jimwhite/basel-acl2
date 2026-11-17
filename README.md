# Basel bounds in ordinary ACL2

This package implements the fixed-precision version of the proposed transfer
of Ruben Gamboa's ACL2(r) Basel proof to ordinary ACL2. It uses one explicitly
trusted, rational-only theorem. All subsequent reasoning is proved in ACL2.

**Scope:** the pi interval has fixed width 10^-20. This package proves finite
bounds and a rational Cauchy estimate. It does not claim to represent pi as an
ordinary ACL2 number or to prove exact equality with pi^2/6 in ordinary ACL2.
The rational endgame is parameterized by interval endpoints, so it can be
reused with a future arbitrary-precision pi enclosure.

Both the ordinary ACL2 books and the generated ACL2(r) exporter certified
successfully. See `VALIDATION.md` and `evidence/` for details.

## Origin

This is a vibed attempt (ChatGPT Astra high) at implementing Matt Kaufmann's question / suggestion for Ruben Gamboa's rump session talk at ACL2 Workshop 2026: *An Alternative Proof in ACL2(r) of Euler's Solution to the Basel Problem*.  The only part that I sort of understood was the idea to be able to use the proof done in ACL2(r) in regular ACL2 and that it involved the use of rational bounds rather than reals.

The ChatGPT session: https://chatgpt.com/share/6afccfd5-2fd0-83e8-969c-5b958e29943f

## Results

`(bq-sum N)` means sum(j = 1,...,N) 1/j^2, including N. Define

```
L = 314159265358979323846 / 100000000000000000000
U = 314159265358979323847 / 100000000000000000000
```

The main theorems are:

| Theorem | Statement / role |
| --- | --- |
| `bq-fixed-basel-bounds` | For positive n, L^2/6 - (L^2+2)/(6*2^n) <= S_(2^n) <= U^2/6. |
| `bq-fixed-all-partial-sums-bound` | For every positive N, L^2/6 - 3/N <= S_N <= U^2/6. |
| `bq-fixed-width-bound` | Dyadic enclosure width is less than 10^-19 + 2/2^n. |
| `bq-partial-sums-tail` | For 1 <= m <= n, 0 <= S_n-S_m <= 1/m-1/n. No trust tag. |
| `bq-cauchy-bound` | If eps > 0 and m*eps >= 1, then for n >= m, abs(S_n-S_m) <= eps. No trust tag. |
| `bq-finite-enclosure-from-odd-bound` | Parameterized ordinary ACL2 endgame, conditional on an odd-sum enclosure with rational endpoints lo and hi. No trust tag. |
| `bq-demo-2-to-80-terms` | Encloses S_(2^80) between 1.644934066848226436 and 1.644934066848226437, without evaluating its summands. |

The exact dyadic interval width is

```
(U^2 - L^2)/6 + (L^2 + 2)/(6*2^n).
```

## Files and trust boundary

- `rational-defs.lisp`: shared, executable rational definitions. The two
  upstream range sums use EXCLUSIVE upper endpoints. `bq-sum` supplies the
  extra 1 needed for an inclusive mathematical partial sum.
- `rational-proofs.lisp`: type, splitting, telescoping, error propagation,
  and Cauchy proofs. It contains no trust tags or skipped proofs.
- `trusted-bridge.lisp`: imports exactly `(bq-fixed-odd-enclosure n)` using
  `define-trusted-clause-processor` and the tag
  `:basel-acl2r-finite-bounds`.
- `basel-rational.lisp`: combines the import and rational endgame.
- `demo.lisp`: large-index symbolic demonstration.
- `acl2r-export-tail.lsp`: the ACL2(r) theorem to prove from the original
  finite analytic bounds and `pi-tight-bound`.
- `prepare-acl2r.py`: checks pinned upstream source hashes and constructs a
  separate ACL2(r) proof workspace. It does not change the upstream checkout.
- `.acl2` files: narrowly scoped certification permission for the trust tag.

The processor recognizes ONLY the exact singleton clause

```lisp
((bq-fixed-odd-enclosure n))
```

and returns every other clause unchanged. It does not accept arbitrary
ACL2(r) output, run an external prover, verify a certificate, or silently
translate analytic formulas. Its supporters record the concrete shared
function definitions. The function contains no raw Lisp, shell calls, or
attachments. Negative recognition checks are included in the book.

This is a **manually audited trusted theorem import**. The trust obligation
is that the rational-only proposition proved in ACL2(r) has the same meaning
under the shared definitions in ordinary ACL2, for all ordinary integer n.
The tag records that obligation; it does not prove a general transfer theorem
between ACL2 and ACL2(r).

The imported theorem says, for positive n,

```
L^2 * (1/8 - 1/2^(n+3))
  <= sum(j = 1,...,2^(n-1)) 1/(2*j-1)^2
  <= U^2/8.
```

It does not import the final Basel conclusion. The ordinary ACL2 proof derives
the full-sum bounds from the odd-sum bounds, the odd/even split, and a new
rational telescoping proof. No `skip-proofs` or `defaxiom` is used in the new
books.

## Certifying the ordinary ACL2 books

Use a built ACL2 checkout with Community Books. Run from this directory:

```sh
ACL2_ROOT=/absolute/path/to/ordinary-acl2
"$ACL2_ROOT/books/build/cert.pl" \
  --acl2 "$ACL2_ROOT/saved_acl2" demo.lisp
```

`cert.pl` builds the dependencies and reads the tag permissions from the
corresponding `.acl2` files. To build only the core result, use
`basel-rational.lisp` instead of `demo.lisp`.

To use the certified result:

```lisp
(include-book "basel-rational"
              :ttags (:basel-acl2r-finite-bounds))
```

To use the independently proved rational lemmas without trusting an import:

```lisp
(include-book "rational-proofs")
```

The shared definitions are deliberately executable, so do not evaluate
`bq-sum` at enormous indices. `demo.lisp` shows a restricted proof theory for
using the bound symbolically instead.

## Reproducing the ACL2(r) source proof

Use a SEPARATE ACL2(r) build and certificate tree. The checked source revision
is:

```
Repository: https://github.com/acl2/acl2
Branch at time of investigation: acl2r-context
Commit: 330a2344fa44d08fbd5fbf24c4b44a7473c9803d
```

The upstream books are under `books/nonstd/basel/`. The required finite
lemmas are local to `basel-series.lisp`, so an ordinary include-book cannot
expose them. The preparation script makes a copy that imports the shared
definitions near the beginning and appends the export theorem immediately after the last finite bound,
while the local lemmas remain available during certification. It keeps the
preceding proof events unchanged, but omits the later limit argument and
replaces the integral-based `basel-bound` include with the shared rational
definitions. The earlier proof uses `basel-series` only as an induction
scheme; it does not need the integral estimates.

```sh
ACL2R_ROOT=/absolute/path/to/separate-acl2r-checkout
python3 prepare-acl2r.py "$ACL2R_ROOT" acl2r-work
cd acl2r-work
"$ACL2R_ROOT/books/build/cert.pl" \
  --acl2 "$ACL2R_ROOT/saved_acl2r" acl2r-export.lisp
```

The generated workspace has its own copy of `rational-defs.lisp`, so ACL2(r)
certification cannot overwrite the ordinary ACL2 certificate. Do not mix
certificates from the two systems.

The preparation script verifies the SHA-256 of the three upstream Basel
sources. It refuses changed sources and a nonempty output directory. Its
manifest records inputs, not proof success. For a different upstream
revision, review the source changes before changing these hashes.

## Extending to arbitrary precision

The reusable theorem `bq-finite-enclosure-from-odd-bound` already accepts
arbitrary rational `lo` and `hi`. To obtain a full rational-sequence statement
of the Basel identity, add concrete rational functions `pi-lo(p)` and
`pi-hi(p)`, prove their relation to pi in ACL2(r), prove their shrinking width
in ACL2, and replace the single fixed-precision export with a corresponding
precision-indexed export. Keep the same finite endgame.

Do not constrain a single ordinary ACL2 number to lie in every progressively
tighter interval for pi: ordinary ACL2's real-valued numbers are rational.

## Sources and attribution

- Ruben Gamboa, *An Alternative Proof in ACL2(r) of Euler's Solution to the
  Basel Problem*, ACL2 Workshop 2026:
  https://www.cs.utexas.edu/~moore/acl2/workshop-2026/slides/basel-talk.pdf
- Pinned Basel source:
  https://github.com/acl2/acl2/tree/330a2344fa44d08fbd5fbf24c4b44a7473c9803d/books/nonstd/basel
- Pi bounds: `books/nonstd/nsa/trig.lisp`, especially `m-pi`, `m-pi+eps`, and
  `pi-tight-bound`.
- Trusted clause processor documentation:
  https://www.cs.utexas.edu/~moore/acl2/v6-2/DEFINE-TRUSTED-CLAUSE-PROCESSOR.html

The range-sum definitions and elementary power-of-two induction track the
upstream definitions/proof. The new rational endgame, import wrapper, export
adapter, and preparation script were written for this package. Upstream
source files are obtained from the user's checkout by the preparation
script, rather than bundled as a replacement for that project.
