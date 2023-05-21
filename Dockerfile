# get newest certificates
FROM --platform=$BUILDPLATFORM alpine:3.16 AS ca-certs
RUN apk add --no-cache ca-certificates
RUN --mount=type=cache,target=/etc/ssl/certs \
    update-ca-certificates 2>/dev/null || true

# zig compiler
FROM --platform=$BUILDPLATFORM ghcr.io/euantorano/zig:master AS zig-env

# build environment
FROM --platform=$BUILDPLATFORM golang:1-alpine AS build

# setup zig & zigtool
COPY --from=zig-env /usr/local/bin/zig /usr/local/bin/zig
ENV PATH="/usr/local/bin/zig:${PATH}" \
    CC="zigcc" \
    CXX="zigcpp" \
    CGO_ENABLED=0 \
    GOOS="linux"
RUN --mount=type=cache,target=/go/pkg \
    go install github.com/dosgo/zigtool/zigcc@latest && \
    go install github.com/dosgo/zigtool/zigcpp@latest

# fix vulnerabilities
RUN --mount=type=cache,target=/go/pkg \
    cd /usr/local/go/src && \
    go get -u golang.org/x/sys golang.org/x/net golang.org/x/text golang.org/x/crypto && \
    cd /usr/local/go/src/crypto/internal/edwards25519/field/_asm && \
    go get -u github.com/mmcloughlin/avo golang.org/x/mod golang.org/x/sys golang.org/x/tools golang.org/x/xerrors && \
    cd /usr/local/go/src/crypto/internal/bigmod/_asm && \
    go get -u github.com/mmcloughlin/avo golang.org/x/mod golang.org/x/sys golang.org/x/tools golang.org/x/xerrors


# cleanup
RUN go clean -cache && \
    go clean -modcache

# copy latest certificates
COPY --from=ca-certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# set working directory
WORKDIR /go/src

# GOARCH ONBUILD
ONBUILD ARG TARGETARCH
ONBUILD ENV GOARCH=$TARGETARCH 

# GOARM ONBUILD
ONBUILD ARG TARGETVARIANT
ONBUILD RUN go env -w GOARM=${TARGETVARIANT##*v}