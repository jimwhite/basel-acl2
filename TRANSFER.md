# ACL2(r)-to-ACL2 transfer: contract and trust boundary

This project uses ACL2(r) to prove a rational finite-sum bound, then imports
that result into ordinary ACL2 so the remaining arithmetic proofs can run
there. The transfer is deliberately limited to a checked event interface.
It is not a general ACL2(r) book importer, a verified transfer theorem, or a
proof that arbitrary ACL2(r) results are valid in ordinary ACL2.

## What is an `.r2a` file?

`.r2a` is a project-specific file suffix, not an ACL2-standard extension.
Here, the file is a versioned ACL2-readable data object with this shape:

```lisp
(:r2a-v1 "<ACL2 version>" (<portable events> ...))
```

It carries the selected event interface from ACL2(r) to the ordinary ACL2
importer; it is not an ACL2 book to include directly and not a proof
certificate. The importer reads the object as data, checks its shape and
portable-event interface, and then processes those events under the trust
boundary described below. The receipt does not let ordinary ACL2 verify the
source proof on its own.

ACL2's usual distribution mechanism is a book of events, certified and then
included in a compatible ACL2 world (see the ACL2
[Books documentation](https://acl2.org/doc/index-seo.php?xkey=ACL2____BOOKS)).
This receipt is deliberately separate: it represents a narrow handoff
between ACL2(r) and ordinary ACL2, rather than claiming to be a portable
book or certificate. The suffix distinguishes that role for users and tools,
but is not itself a security measure. This is a small project-specific
format, so its version tag and importer checks are part of the interface
that must be maintained.

## How to run the workflow

For the standard workflow, use the commands in [README.md](README.md):

```sh
scripts/acl2r-reproduce.sh
scripts/acl2-certify.sh build/acl2r/new-basel.r2a
```

The first script checks the ACL2(r) source proof and regenerates
`build/acl2r/new-basel.r2a`. The second imports that receipt and certifies the
ordinary ACL2 client. To use the distributed receipt without rerunning the
source proof, run `scripts/acl2-certify.sh`.

The source-side API is `r2a-export-development` followed, after successful
book certification and inclusion, by a separate top-level call to
`r2a-write-export`. In ordinary ACL2, include `transfer` and call
`r2a-import` on the generated receipt. The small example in
`example-export.lsp` and `example-import.lisp` illustrates that API.

## What is checked and transferred

There are two event streams:

- The **source proof** runs normally in ACL2(r). It may use analytic
  definitions, nonstandard analysis, and local proof helpers.
- The **portable interface** is the event sequence retained by
  `r2a-export-development`. Its definitions and theorem statements are
  checked against the supported ordinary-ACL2 vocabulary before transfer.

Local events outside nontrivial encapsulates are omitted from the interface,
including locals inside trivial encapsulates. The source proof still has to
admit and prove the original events normally. Inside a nontrivial
encapsulate, the full event subtree is retained and checked, including local
witnesses and nested scopes. Proof hints are discarded during export.

This distinction allows analytic helpers to support the source proof without
being introduced into ordinary ACL2. It does not allow an unchecked helper
to appear in a retained definition, theorem formula, or encapsulate witness.
After a nonempty encapsulate, constrained functions and definitions from its
scope are not added to the vocabulary for subsequent exports. This avoids
treating an abstract function's ACL2(r) existence assumptions as ordinary
ACL2 facts.

The supported interface is intentionally small:

- `defun` with an ordinary body, optionally with one
  `(declare (xargs :measure ...))`. The receiving ACL2 proves termination.
- `defthm`, optionally with source `:hints` and `:rule-classes`. The imported
  theorem receives `:rule-classes nil`.
- `local` and nested `encapsulate`.
- Nonempty encapsulate signatures of the form `((f (x ...) t) ...)`, with a
  direct local `defun` witness for each signature function.

The term checker allows a limited, explicit set of arithmetic and list
operations, predicates, basic macros, and earlier portable definitions. It
handles `QUOTE`, `LET`, and `LET*` explicitly. Unsupported forms, arbitrary
macros, named constants, and non-ordinary-ACL2 data are rejected. In
particular, the interface does not allow `include-book`, `make-event`,
`defmacro`, `defconst`, `defchoose`, `defun-sk`, `defun-std`, `defaxiom`,
`skip-proofs`, or raw Lisp.

The older `r2a-export` entry point accepts an explicitly supplied interface
without projection. It has the same restricted checking boundary.

## Trusted events and receipt handling

For each imported theorem, the importer creates a local trusted clause
processor accepting only the clause derived for that theorem, with explicit
supporters and tag `:acl2r-checked-transfer`. Definitions are admitted
normally. The auxiliary predicates, processors, and supporting facts are
local, so they cannot outlive the local definitions on which they rely.

The receipt is data produced by an ACL2(r) run; ordinary ACL2 does not verify
it as a proof certificate. It is not cryptographically authenticated.
Do not edit receipts or populate the export table manually. The source
checker, event generator, receipt-writing path, source proof, correspondence
of definitions across the two systems, and receipt provenance are all part
of the trust obligation.

The source checks require the original events to succeed with proofs enabled.
After both the interface check and the original source events succeed, a
fresh trust-state check rejects trust tags, skipped proofs, redefinitions,
and added axioms. The export is recorded only after these checks; writing it
is a separate command after certification.

## Why the restrictions matter

An ACL2(r) theorem can depend on irrational witnesses even when its
conclusion looks rational. For example, a local witness that defines a
function as `(sqrt 2)` cannot safely be treated as an ordinary ACL2
definition. The checker rejects this case and aliases through
nonportable definitions; it does not infer safety from the theorem's
operators alone.

Abstract functions are another hazard. In ACL2(r), an encapsulate
constraint may be justified by an irrational witness; ordinary ACL2 may not
be able to satisfy the same constraint. Retaining and checking the local
witnesses is therefore essential, and the post-encapsulate vocabulary
restriction prevents later transfers from relying on an unsound
interpretation of the abstraction.

The checker is ACL2 `:program` code. This project tests the accepted and
rejected cases, but does not prove the checker's soundness or prove a general
conservativity result. Extending the syntax or changing the abstract-function
policy requires a new soundness review and regression tests.

For this Basel development, the transferred theorem bounds a finite odd
reciprocal-square sum using rational endpoints. The analytic source helpers
remain in ACL2(r); the ordinary ACL2 partial-sum bounds, telescoping
estimates, and executable interval are proved on the receiving side. See
[Adapt ACL2r Proof.md](Adapt%20ACL2r%20Proof.md) for the mathematical
derivation and [VALIDATION.md](VALIDATION.md) for the tested results.
