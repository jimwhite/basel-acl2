# Basel bounds with ACL2 and ACL2(r)

This project proves explicit rational bounds on the partial sums

```text
S_N = 1 + 1/2^2 + ... + 1/N^2
```

The analytic finite bound is proved in ACL2(r). A checked, restricted
interface transfers its rational result to ordinary ACL2, where the remaining
finite-sum arguments and executable interval are proved. The transfer uses
the trust tag `:acl2r-checked-transfer`; it is not a verified general-purpose
importer. Read [TRANSFER.md](TRANSFER.md) before relying on that boundary.

There is no intermediate export file. ACL2(r) certifies
[`basel-export.lisp`](basel-export.lisp), a book whose only event is an
`r2a-export` of the Basel development. Ordinary ACL2 certifies
[`basel-import.lisp`](basel-import.lisp), which calls
`(r2a-import "basel-export")`: it reads the same source book, derives the
same portable interface with the same code, checks it, and admits it. Both
steps are ordinary book certifications driven by `cert.pl`.

## Quick start: use the dev container

The recommended setup supplies both ACL2 flavors with separate books and
certificate trees. You do not need to install SBCL or ACL2 on the host.

1. Open this repository in VS Code with the Dev Containers extension, or
   create a Codespace from the repository.
2. Choose **Dev Containers: Reopen in Container** if VS Code has not already
   opened the repository in its container. Wait for the image build to finish.
3. In the container terminal, certify both sides, ACL2(r) first:

   ```sh
   scripts/acl2r-certify.sh
   scripts/acl2-certify.sh
   ```

The ACL2(r) step proves the analytic source development (about 70 seconds)
and runs the export tests. The ACL2 step imports the export and certifies
the clients and import tests. All checks are in the books; each script just
runs `cert.pl` on a fresh copy of the sources.

The first container build downloads and compiles the dependencies. It needs
at least 2 CPUs, 8 GB of memory, and 32 GB of storage; allow roughly
10–25 minutes for the initial build. The built image is about 5.2 GB.

ACL2 and ACL2(r) both write `.cert` files for the shared books (`transfer`,
`rational-defs`), so the scripts certify in separate fresh, ignored
directories, `build/acl2r/` and `build/acl2/`, and write `cert.log` there.
They recreate those directories on each run, and return a nonzero status if
certification fails.

To try the interval interactively after running the ordinary certification:

```sh
cd build/acl2
acl2
```

At the ACL2 prompt, load the client and evaluate an interval:

```lisp
(include-book "basel-interval" :ttags ((:acl2r-checked-transfer)))
(bq-basel-interval 100000000000000000000)
```

The result is a pair `(lower . upper)` of exact rational numbers. The
function computes the enclosure from its index; it does not calculate the
partial sum. For `N >= 10^20`, the proved enclosure is within
`[1.644934066848226436, 1.644934066848226437]` and has width less than
`10^-19`.

## What is proved

For positive `N`, the executable `bq-basel-interval(N)` encloses `S_N`.
Its endpoints are

```text
lower = L^2/6 - 3/N
upper = U^2/6
```

where `L` and `U` are fixed rational bounds on pi, separated by
`10^-20`. The fixed endpoints impose a precision floor: increasing `N`
alone cannot make the interval arbitrarily narrow. The results are finite
bounds and a rational Cauchy estimate, not an ordinary-ACL2 representation
of pi or a proof using arbitrary-precision pi bounds.

For the mathematical derivation, see the original ChatGPT Astra session (https://chatgpt.com/share/6aff647f-fccc-83e8-8ff6-1907b1c49545) or this .md version [Adapt%20ACL2r%20Proof.md](Adapt%20ACL2r%20Proof.md).

For details on accepted transfer events, trust assumptions, and limitations,
see [TRANSFER.md](TRANSFER.md). The latest validation setup and recorded
results are in [VALIDATION.md](VALIDATION.md).

## Using your own ACL2 installations

The scripts default to `/opt/acl2` and `/opt/acl2r` in the dev container.
Outside it, set `ACL2_ROOT` and `ACL2R_ROOT` to your respective installations
(or set `ACL2` and `ACL2R` to the executable paths). Ordinary ACL2 and ACL2(r)
must use separate source/book trees and separate package build directories;
their `.cert` files cannot be shared. See the script headers and
[TRANSFER.md](TRANSFER.md) for the manual workflow and trust contract.
