# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM alpine:edge

RUN --mount=type=cache,target=/var/cache/apk \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
  # update packages
  apk update && \
  apk upgrade && \
  # install build tools and go
  apk add build-base make libcap musl-dev coreutils go zig

# install zigcc and zigcpp
RUN --mount=type=cache,target=/go/pkg \
  --mount=type=cache,target="/root/.cache/go-build" \
  go install github.com/dosgo/zigtool/zigcc@latest && \
  go install github.com/dosgo/zigtool/zigcpp@latest

# set environment variables
ENV CC="zigcc" \
  CXX="zigcpp" \
  CGO_ENABLED=0 \
  GOOS="linux"

# set working directory
WORKDIR /go/src

# GOARCH ONBUILD
ONBUILD ARG TARGETARCH
ONBUILD RUN go env -w GOARCH=$TARGETARCH 

# GOARM ONBUILD
ONBUILD ARG TARGETVARIANT
ONBUILD RUN go env -w GOARM=${TARGETVARIANT##*v}
