# Validation record

The commands in [README.md](README.md) are the supported end-to-end checks:

```sh
scripts/acl2r-certify.sh
scripts/acl2-certify.sh
```

The first certifies, with ACL2(r), `basel-export` (and so the analytic
source proof in `basel-analytic`), `example-export`, `export-tests` and
`transfer-tests`. The second certifies, with ordinary ACL2, `basel-import`
and its clients `basel-rational`, `basel-interval` and `demo`, as well as
`example-import`, `import-tests` and `transfer-tests`. Every check is an
event in these books (`assert-event`, `must-fail`, or a successful
`include-book`), so a passing run means every book certified. Certificates
and `cert.log` are written under the ignored `build/acl2r/` and
`build/acl2/`.

## Validated configuration

The most recent full validation recorded here used:

- SBCL 2.2.9.debian.
- Ordinary ACL2 and ACL2(r) from the ACL2 `master` commit
  `043ce2f2e51aa3dd7fde519be0b1091d7bc4077a`.
- For ACL2(r), `books/nonstd` from commit
  `330a2344fa44d08fbd5fbf24c4b44a7473c9803d` on `acl2r-context`. The Basel
  books and a required nonstandard-analysis book are not present on `master`.

The devcontainer configuration builds ACL2 from `master` with SBCL 2.6.10 and
overlays that pinned `books/nonstd` tree for ACL2(r). That image has not been
re-validated since the move to book-based export and import. Since `master`
is a moving reference, a later image build may use a different ACL2 commit.

## Results

In the recorded configuration:

- ACL2(r) certified all of its targets; `basel-analytic` took about 70
  seconds. `export-tests` confirmed:
  - the recorded Basel interface;
  - that the importer's reading of `basel-export` and `example-export`
    matches what ACL2(r) recorded;
  - rejection of a false theorem, a false local lemma, Matt's irrational
    encapsulate witness, `defchoose`, a leaked local definition, a skipped
    local proof, a system `include-book`, and a nonportable sibling book.
- Ordinary ACL2 certified all of its targets. `import-tests` confirmed:
  - that `transfer` and `rational-proofs` include with `:ttags nil`;
  - that `bq-basel-interval` at `N = 10^20` has exact width
    `809439510239319549231 / 20000000000000000000000000000000000000000`,
    which is less than `10^-19`;
  - rejection by `r2a-import`, independently of ACL2(r), of a reader
    conditional, an extra event in an export book, an irrational witness,
    an included nonportable sibling book, and a non-export book.
- Each script refused to run with the other flavor's executable.

The `cert.log` files and the `.cert.out` outputs of the export, import and
test books from this run are in [`evidence/`](evidence/), together with the
source hashes in
[`evidence/source-manifest.json`](evidence/source-manifest.json).

## What this validation establishes

The runs establish that the listed books certified and the tested boundary
cases behaved as expected in the recorded configuration. They do not prove
the transfer checker's soundness, establish that the export book was
actually certified in ACL2(r) before an import, or
remove the documented trust obligations. They also do not extend the fixed
rational pi enclosure to arbitrary precision. See [TRANSFER.md](TRANSFER.md)
for the trust boundary and [Adapt ACL2r Proof.md](Adapt%20ACL2r%20Proof.md)
for the mathematical result.
