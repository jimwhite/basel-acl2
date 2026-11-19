# Shared image for the two development containers in this directory.
#   ACL2_FLAVOR=acl2   ordinary ACL2   (/opt/acl2/saved_acl2)
#   ACL2_FLAVOR=acl2r  ACL2(r)         (/opt/acl2/saved_acl2r)
# Both are built from the master branch of https://github.com/acl2/acl2 with
# SBCL built from the upstream release tag.

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
ARG ACL2_FLAVOR=acl2
ARG ACL2_REF=master
# The Basel books exist only on the ACL2 `acl2r-context` branch (this commit).
# For ACL2(r), books/nonstd is taken from it on top of master. See README.md.
ARG NONSTD_REF=330a2344fa44d08fbd5fbf24c4b44a7473c9803d
ARG CERT_JOBS=2

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential ca-certificates git perl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=sbcl /usr/local/bin/sbcl /usr/local/bin/sbcl
COPY --from=sbcl /usr/local/lib/sbcl /usr/local/lib/sbcl

ENV ACL2_ROOT=/opt/acl2 \
    ACL2_FLAVOR=${ACL2_FLAVOR}

RUN set -eux; \
    case "${ACL2_FLAVOR}" in acl2|acl2r) ;; *) echo "bad ACL2_FLAVOR"; exit 1;; esac; \
    git init -q "${ACL2_ROOT}"; cd "${ACL2_ROOT}"; \
    git remote add origin https://github.com/acl2/acl2.git; \
    git fetch -q --depth 1 origin "${ACL2_REF}"; \
    git checkout -q FETCH_HEAD; \
    git rev-parse HEAD > ACL2_COMMIT; \
    if [ "${ACL2_FLAVOR}" = acl2r ]; then \
      git fetch -q --depth 1 origin "${NONSTD_REF}"; \
      git checkout -q FETCH_HEAD -- books/nonstd; \
      echo "${NONSTD_REF}" > NONSTD_COMMIT; \
    fi; \
    rm -rf .git; \
    chown -R vscode:vscode "${ACL2_ROOT}"

USER vscode
WORKDIR /opt/acl2
# Build ACL2 or ACL2(r), then certify the Community Books this package needs.
# .git was removed to save space, so supply the startup-banner commit directly.
RUN set -eux; \
    export ACL2_SNAPSHOT_INFO="Git commit hash: $(cat ACL2_COMMIT)"; \
    if [ "${ACL2_FLAVOR}" = acl2r ]; then \
      make LISP=sbcl ACL2_REAL=r || { tail -60 make.log; exit 1; }; ACL2=/opt/acl2/saved_acl2r; \
      books="arithmetic-5/top nonstd/nsa/sqrt nonstd/nsa/exp nonstd/nsa/norm \
             nonstd/nsa/trig nonstd/nsa/complex-polar nonstd/nsa/raise \
             nonstd/nsa/standard-close-utils nonstd/basel/complex-helper"; \
    else \
      make LISP=sbcl || { tail -60 make.log; exit 1; }; ACL2=/opt/acl2/saved_acl2; \
      books="arithmetic-5/top"; \
    fi; \
    test -x "$ACL2"; \
    rm -f *.o; \
    cd books; \
    ./build/cert.pl --acl2 "$ACL2" -j "${CERT_JOBS}" $books

USER root
RUN if [ "${ACL2_FLAVOR}" = acl2r ]; then \
      ln -s /opt/acl2/saved_acl2r /usr/local/bin/acl2r; \
    else \
      ln -s /opt/acl2/saved_acl2 /usr/local/bin/acl2; \
    fi
USER vscode
WORKDIR /home/vscode
