# Validation record

The commands in [README.md](README.md) are the supported end-to-end checks:

```sh
scripts/acl2r-reproduce.sh
scripts/acl2-certify.sh
scripts/acl2-certify.sh build/acl2r/new-basel.r2a
```

The first command certifies the ACL2(r) source-side books, regenerates the
receipt, compares it with `basel.r2a`, and runs export regressions. The
second certifies ordinary ACL2 client books with the distributed receipt.
The third certifies them with the newly generated receipt. Logs are written
under `build/acl2r/logs/` and `build/acl2/logs/`; generated certificates and
other build files stay in the ignored `build/` directory.

## Validated configuration

The most recent full validation recorded here used:

- SBCL 2.6.10, built from its release source tag.
- Ordinary ACL2 and ACL2(r) from the ACL2 `master` commit
  `043ce2f2e51aa3dd7fde519be0b1091d7bc4077a`.
- For ACL2(r), `books/nonstd` from commit
  `330a2344fa44d08fbd5fbf24c4b44a7473c9803d` on `acl2r-context`. The Basel
  books and a required nonstandard-analysis book are not present on `master`.

The devcontainer configuration builds ACL2 from `master` and overlays that
pinned `books/nonstd` tree for ACL2(r). Since `master` is a moving reference,
a later image build may use a different ACL2 commit; the tested commit is
recorded in this report and in the evidence directory.

## Results

In the recorded configuration:

- The ACL2(r) source books certified, the Basel source proof completed, and
  the regenerated `new-basel.r2a` matched `basel.r2a` byte-for-byte.
- The example receipt also reproduced byte-for-byte.
- The development-source tests ended with
  `:DEVELOPMENT-SOURCE-TESTS-PASSED`; the export-failure tests ended with
  `:ALL-EXPECTED-EXPORT-FAILURES-CHECKED`.
- Ordinary ACL2 certified the client books. The `transfer` and
  `rational-proofs` books included with `:ttags nil`.
- Ordinary ACL2 evaluated `bq-basel-interval` at `N = 10^20`; its exact
  width was
  `809439510239319549231 / 20000000000000000000000000000000000000000`,
  which is less than `10^-19`.
- The scripts rejected using the other ACL2 flavor's executable. Ordinary
  ACL2 also rejected a book certified by ACL2(r).

Detailed captured logs for this run are in
[`evidence/master-sbcl-2.6.10/`](evidence/master-sbcl-2.6.10/). Other files
under `evidence/` preserve results from earlier validation runs; they are
not the current configuration.

## What this validation establishes

The runs establish that the listed books certified and the tested boundary
cases behaved as expected in the recorded configuration. They do not prove
the transfer checker's soundness, authenticate receipt provenance, or
remove the documented trust obligations. They also do not extend the fixed
rational pi enclosure to arbitrary precision. See [TRANSFER.md](TRANSFER.md)
for the trust boundary and [Adapt ACL2r Proof.md](Adapt%20ACL2r%20Proof.md)
for the mathematical result.
