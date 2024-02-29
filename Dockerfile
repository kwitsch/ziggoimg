# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM golang:1-alpine

# fix vulnerabilities in alpine
RUN --mount=type=cache,target=/var/cache/apk \
  echo "edge" > /etc/alpine-release && \
  apk update && \
  apk upgrade && \
  apk add build-base make libcap musl-dev coreutils 
# fix vulnerabilities in go libraries
WORKDIR /usr/local/go/src
RUN --mount=type=cache,target=/go/pkg \
  --mount=type=cache,target="/root/.cache/go-build" \
  go get -u golang.org/x/sys golang.org/x/net golang.org/x/text golang.org/x/crypto && \
  for D in $(find / -name "go.mod" | sed -r 's|/[^/]+$||'); do echo "upgrading: $D" && cd $D && go get -u ./... && go mod tidy -v || echo "error while upgrading"; done && \
  echo "vendorizing..." && \
  rm -R vendor && \
  go mod vendor -v

# setup zig & zigtool
COPY zigdir /usr/local/bin/zig
ENV PATH="/usr/local/bin/zig:${PATH}" \
  CC="zigcc" \
  CXX="zigcpp" \
  CGO_ENABLED=0 \
  GOOS="linux"
RUN --mount=type=cache,target=/go/pkg \
  --mount=type=cache,target="/root/.cache/go-build" \
  go install github.com/dosgo/zigtool/zigcc@latest && \
  go install github.com/dosgo/zigtool/zigcpp@latest

# set working directory
WORKDIR /go/src

# GOARCH ONBUILD
ONBUILD ARG TARGETARCH
ONBUILD RUN go env -w GOARCH=$TARGETARCH 

# GOARM ONBUILD
ONBUILD ARG TARGETVARIANT
ONBUILD RUN go env -w GOARM=${TARGETVARIANT##*v}
