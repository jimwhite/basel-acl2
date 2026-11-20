# One image with two independent ACL2 installations, each with its own
# Community Books tree and certificates:
#   /opt/acl2   ordinary ACL2  (saved_acl2,  on PATH as `acl2`)
#   /opt/acl2r  ACL2(r)        (saved_acl2r, on PATH as `acl2r`)
# Certificates are never shared between them. Both are built from the master
# branch of https://github.com/acl2/acl2 with SBCL built from its release tag.

ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# ---------------------------------------------------------------------------
# SBCL, built from source. Ubuntu's packaged SBCL is only the bootstrap host.
FROM ${BASE_IMAGE} AS sbcl
ARG SBCL_VERSION=2.6.10
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl sbcl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/sbcl
RUN curl -fsSL "https://github.com/sbcl/sbcl/archive/refs/tags/sbcl-${SBCL_VERSION}.tar.gz" \
      | tar xz --strip-components=1 \
 && printf '"%s"\n' "${SBCL_VERSION}" > version.lisp-expr \
 && sh make.sh --prefix=/usr/local --with-sb-thread \
 && sh install.sh \
 && /usr/local/bin/sbcl --non-interactive \
      --eval '(progn (princ (lisp-implementation-version)) (terpri))'

# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE}
ARG ACL2_REF=master
# The Basel books exist only on the ACL2 `acl2r-context` branch (this commit).
# For ACL2(r) only, books/nonstd is taken from it on top of master.
ARG NONSTD_REF=330a2344fa44d08fbd5fbf24c4b44a7473c9803d
ARG CERT_JOBS=2

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential ca-certificates git perl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=sbcl /usr/local/bin/sbcl /usr/local/bin/sbcl
COPY --from=sbcl /usr/local/lib/sbcl /usr/local/lib/sbcl

# Fetch sources once; /opt/acl2r is a separate copy with the nonstd overlay.
# .git is removed to save space, so the commit is recorded in ACL2_COMMIT.
RUN set -eux; \
    git init -q /opt/acl2; cd /opt/acl2; \
    git remote add origin https://github.com/acl2/acl2.git; \
    git fetch -q --depth 1 origin "${ACL2_REF}"; \
    git checkout -q FETCH_HEAD; \
    git rev-parse HEAD > ACL2_COMMIT; \
    git fetch -q --depth 1 origin "${NONSTD_REF}"; \
    cp -a /opt/acl2 /opt/acl2r; \
    git -C /opt/acl2r checkout -q FETCH_HEAD -- books/nonstd; \
    echo "${NONSTD_REF}" > /opt/acl2r/NONSTD_COMMIT; \
    rm -rf /opt/acl2/.git /opt/acl2r/.git; \
    chown -R vscode:vscode /opt/acl2 /opt/acl2r

USER vscode

# Ordinary ACL2 and the Community Books this package needs.
WORKDIR /opt/acl2
RUN set -eux; \
    export ACL2_SNAPSHOT_INFO="Git commit hash: $(cat ACL2_COMMIT)"; \
    make LISP=sbcl || { tail -60 make.log; exit 1; }; \
    test -x saved_acl2; rm -f *.o; \
    books/build/cert.pl --acl2 /opt/acl2/saved_acl2 -j "${CERT_JOBS}" \
      books/arithmetic-5/top books/std/testing/must-fail

# ACL2(r) and the nonstandard-analysis books needed by the Basel source.
WORKDIR /opt/acl2r
RUN set -eux; \
    export ACL2_SNAPSHOT_INFO="Git commit hash: $(cat ACL2_COMMIT)"; \
    make LISP=sbcl ACL2_REAL=r || { tail -60 make.log; exit 1; }; \
    test -x saved_acl2r; rm -f *.o; \
    cd books; \
    ./build/cert.pl --acl2 /opt/acl2r/saved_acl2r -j "${CERT_JOBS}" \
      arithmetic-5/top nonstd/nsa/sqrt nonstd/nsa/exp nonstd/nsa/norm \
      nonstd/nsa/trig nonstd/nsa/complex-polar nonstd/nsa/raise \
      nonstd/nsa/standard-close-utils nonstd/basel/complex-helper \
      std/testing/must-fail

USER root
RUN ln -s /opt/acl2/saved_acl2 /usr/local/bin/acl2 \
 && ln -s /opt/acl2r/saved_acl2r /usr/local/bin/acl2r
USER vscode
ENV ACL2_ROOT=/opt/acl2 \
    ACL2R_ROOT=/opt/acl2r
WORKDIR /home/vscode
