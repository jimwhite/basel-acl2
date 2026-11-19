# Transfer contract and soundness boundary

This implements a restricted interpretation of Matt Kaufmann's suggestion:
use an explicit trust tag to transfer ACL2(r)-proved rational results, while
checking the admissibility of the transferred interface, including LOCAL
events inside ENCAPSULATE. It is not a claim to reproduce an unpublished
general book-import design, nor a verified conservativity theorem.

## Two distinct event streams

The analytic proof world may contain pi, square roots, nonstandard analysis,
and its own encapsulates. It is never loaded into ordinary ACL2.

The **portable interface** is the explicit event sequence supplied to
`r2a-export`. Every event in that sequence is checked, including events under
arbitrarily nested LOCAL and ENCAPSULATE. Proof hints may refer to the analytic
world, but hints are discarded when exporting. The bodies of definitions and
the formulas of theorems cannot refer to unchecked analytic functions.

Thus the checker is not claiming that every local event in Ruben's analytic
proof is portable. It checks every local event of the interface actually
transferred. Rejecting all analytic proof steps would defeat the purpose of
using ACL2(r) as the source prover.

## Supported interface

- `defun` with an ordinary body, optionally one `(declare (xargs :measure ...))`.
  The target proves termination normally; termination is not trusted.
- `defthm`, optionally with source `:hints` and `:rule-classes`.
  The target exports the theorem with `:rule-classes nil`.
- `local` and nested `encapsulate`.
- Nonempty signatures in the form `((f (x ...) t) ...)`. Each signature
  function must have a direct `(local (defun f ...))` witness in that scope.

The term checker allows a small explicit vocabulary of shared arithmetic,
list operations, predicates, and basic macros, plus earlier portable
definitions. It handles QUOTE, LET and LET* explicitly. Literal data must
belong to the ordinary ACL2 universe. Named constants and arbitrary macros
are rejected. Function and event forms not explicitly supported are rejected.

In particular, the interface does not accept `include-book`, `make-event`,
`defmacro`, `defconst`, `defchoose`, `defun-sk`, `defun-std`, `defaxiom`,
`skip-proofs`, or raw Lisp. A surrounding source proof book may use normal
ACL2(r) facilities to prove the interface statements.

This is stricter than ACL2(r)'s technical `classicalp` property: being
classical does not imply that a function returns rational results on rational
inputs. Square root is the relevant example.

## Matt's counterexample

This interface is rejected at its local definition:

```lisp
(encapsulate ((my-sqrt-2 () t))
  (local (defun my-sqrt-2 () (sqrt 2)))
  (defthm bad
    (equal (* (my-sqrt-2) (my-sqrt-2)) 2)))
```

The checker also rejects `acl2-sqrt`, aliases introduced through nonportable
definitions, nested local encapsulates, and nonportable local theorems.
It does not infer safety merely from the exported equation's operators.

## A second restriction: abstraction changes the argument

Even a rational witness does not justify transferring every later theorem
about the resulting abstract function. For example:

```lisp
(encapsulate ((c () t))
  (local (defun c () 0))
  (defthm condition-on-c
    (implies (equal (* x x) 2) (equal (c) 0))))
```

In ACL2(r), the constraint implies `(equal (c) 0)` by instantiating x with a
square root of 2. In ordinary ACL2 the constraint is vacuous. Transferring
that subsequent theorem as if it followed from the same constraints would
therefore need an additional justification.

This implementation fails closed: after a nonempty encapsulate, its
constrained functions and the definitions introduced in its scope are not
added to the vocabulary for subsequent transfers. The constraint events
themselves are checked while their explicit portable witnesses are in scope.
Ordinary ACL2 may subsequently reason about the imported constraints, as
`example-import.lisp` demonstrates. A new export starts with an empty
user-function vocabulary; it cannot bypass this restriction by naming an
abstract function already in the source world.

## Source proof and target proof

`r2a-export` checks the complete interface before executing it. It then runs
the source events normally inside an encapsulate, and records the interface
only after both passes succeed. A local-incompatibility failure cannot record
a new export. Source checks reject skipped proofs, trust tags, redefinitions,
and nonconstructive axioms added after the ACL2(r) bootstrap.

File output is a separate top-level `r2a-write-export` command after source
certification. No trust tag is used to write files inside MAKE-EVENT.
The receipt keeps definitions, constraints, and local events; only source
proof hints and rule-class settings are stripped.

The target checks the receipt again. It admits definitions normally and
builds a local predicate for each theorem. A local trusted clause processor
accepts exactly the singleton clause calling that predicate with its free
variables. All other clauses are unchanged. The predicate and visible
interface functions are explicit supporters. An ordinary ACL2 proof then
recovers the original theorem from that local fact.

Auxiliary processors and facts are local, so they cannot outlive the local
definitions on which their correctness depends. The tag survives in the
book's trust-tag accounting.

## What the trust tag means

`:acl2r-checked-transfer` authorizes reliance on:

1. The soundness of the source ACL2(r) proof run.
2. The correspondence of the checked portable vocabulary and definitions
   between ACL2(r) and ordinary ACL2.
3. Correctness of this executable checker and event generator.
4. The receipt genuinely coming from that run without alteration.

The checker is ACL2 `:program` code, not a verified clause processor or a
machine-proved transfer metatheorem. The receipt is not cryptographically
authenticated and is not an ACL2 proof certificate. A fabricated receipt
could claim a false theorem over otherwise portable functions. Neither its
format nor the source-version string establishes proof provenance. The
export table and low-level writing utilities are likewise part of the trusted
workflow; do not populate them manually.

Ordinary certification with this tag verifies the receiving definitions and
all subsequent rational proofs, conditional on those trust obligations.
The tag and explicit checks reduce and expose the trusted work; they do not
eliminate it. Extending the accepted syntax or abstract-function policy needs
a fresh soundness review and tests.
