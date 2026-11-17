#!/usr/bin/env python3
"""Prepare an ACL2(r) proof workspace without changing the upstream checkout.

Usage: python3 prepare-acl2r.py /path/to/acl2r-checkout [output-directory]
Requires the pinned acl2r-context sources described in README.md.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys

PIN = '330a2344fa44d08fbd5fbf24c4b44a7473c9803d'
HASHES = {
    'basel-bound.lisp': 'd3fbffd1fa0533f8868b2291b3921848fdf97c06e3493229c9cf431ebd0c38be',
    'basel-series.lisp': '3aae65ce45678e6f464f0126aa2e63ca3bf24423f1007d083f5cc14c5421e4b4',
    'complex-helper.lisp': '3441855489a317b72590596b4c7a7ffc0ebc63133e1b533cce83bd50c356d8e1',
}

def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    here = Path(__file__).resolve().parent
    acl2 = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve() if len(sys.argv) == 3 else here / 'acl2r-work'
    upstream = acl2 / 'books/nonstd/basel'
    sources = {}
    for name, expected in HASHES.items():
        data = (upstream / name).read_bytes()
        actual = hashlib.sha256(data).hexdigest()
        if actual != expected:
            raise SystemExit(f'{name}: source hash mismatch; review before changing the pin')
        sources[name] = data.decode()
    if out.exists() and any(out.iterdir()):
        raise SystemExit(f'Refusing to overwrite nonempty output directory: {out}')
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(here / 'rational-defs.lisp', out / 'rational-defs.lisp')
    # Retain the upstream prefix through the last finite bound. The later
    # limit proof and integral-based basel-bound book are unnecessary. The
    # shared book supplies the exact basel-series definition used for induction.
    for name in ('complex-helper.lisp',):
        (out / name).write_text(sources[name])
    original = sources['basel-series.lisp']
    cutoff = '(local\n (defthmd big-upper-bound\n'
    if original.count(cutoff) != 1:
        raise SystemExit('Unexpected finite-bound cutoff')
    original = original[:original.index(cutoff)]
    old_include = '(include-book \"basel-bound\")'
    if original.count(old_include) != 1:
        raise SystemExit('Unexpected basel-bound include')
    original = original.replace(old_include, '; basel-series is supplied by rational-defs below.')
    marker = '(in-package "ACL2")'
    if original.count(marker) != 1:
        raise SystemExit('Unexpected upstream package form')
    original = original.replace(marker, marker + '\n(include-book "rational-defs")', 1)
    tail = (here / 'acl2r-export-tail.lsp').read_text()
    (out / 'acl2r-export.lisp').write_text(original + '\n' + tail)
    manifest = {'upstream_commit': PIN, 'upstream_sha256': HASHES,
                'shared_definitions_sha256': hashlib.sha256((here / 'rational-defs.lisp').read_bytes()).hexdigest(),
                'export_tail_sha256': hashlib.sha256(tail.encode()).hexdigest(),
                'theorem': '(bq-fixed-odd-enclosure n)',
                'transformation': 'prefix before big-upper-bound; replace basel-bound include with shared definitions; append export',
                'status': 'prepared; not a certification receipt'}
    (out / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(out)
    print('Certify with this checkout\'s ACL2(r) executable and system books.')

if __name__ == '__main__':
    main()
