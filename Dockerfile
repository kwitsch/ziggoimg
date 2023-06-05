FROM --platform=$BUILDPLATFORM alpine AS zig-env

ARG PUB_KEY=RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U

# fix vulnerabilities
RUN echo "edge" > /etc/alpine-release && \
    apk update && \
    apk upgrade

# setup zig
COPY zig.tar.xz /tmp/zig.tar.xz
COPY zig.tar.xz.minisign /tmp/zig.tar.xz.minisign
RUN apk add --no-cache --virtual .extract-deps tar xz minisign && \
    minisign -Vm /tmp/zig.tar.xz -x /tmp/zig.tar.xz.minisign -P ${PUB_KEY} && \
    mkdir -p "/usr/local/bin/zig" && tar -Jxf /tmp/zig.tar.xz -C "/usr/local/bin/zig" --strip-components=1 && \
    apk del .extract-deps

# remove unnecessary files
RUN rm -R /usr/local/bin/zig/lib/libc/include/any-windows-any && \
    rm -R /usr/local/bin/zig/lib/libc/include/aarch64-macos.11-none && \
    rm -R /usr/local/bin/zig/lib/libc/include/aarch64-macos.12-none && \
    rm -R /usr/local/bin/zig/lib/libc/include/aarch64-macos.13-none && \
    rm -R /usr/local/bin/zig/lib/libc/include/any-macos-any && \
    rm -R /usr/local/bin/zig/lib/libc/include/any-macos.11-any && \
    rm -R /usr/local/bin/zig/lib/libc/include/any-macos.12-any && \
    rm -R /usr/local/bin/zig/lib/libc/include/any-macos.13-any && \
    rm -R /usr/local/bin/zig/doc

# build environment
FROM --platform=$BUILDPLATFORM golang:1-alpine

# fix vulnerabilities
RUN --mount=type=cache,target=/go/pkg \
    echo "edge" > /etc/alpine-release && \
    apk update && \
    apk upgrade && \
    cd /usr/local/go/src && \
    go get -u golang.org/x/sys golang.org/x/net golang.org/x/text golang.org/x/crypto && \
    for D in $(find / -name "go.mod" | sed -r 's|/[^/]+$||'); do echo "upgrading: $D" && cd $D && go get -u ./... && go mod tidy || echo "error while upgrading"; done

# setup zig & zigtool
COPY --from=zig-env /usr/local/bin/zig /usr/local/bin/zig
ENV PATH="/usr/local/bin/zig:${PATH}" \
    CC="zigcc" \
    CXX="zigcpp" \
    CGO_ENABLED=1 \
    GOOS="linux"
RUN --mount=type=cache,target=/go/pkg \
    go install github.com/dosgo/zigtool/zigcc@latest && \
    go install github.com/dosgo/zigtool/zigcpp@latest && \
    go clean -cache && \
    go clean -modcache

# set working directory
WORKDIR /go/src

# GOARCH ONBUILD
ONBUILD ARG TARGETARCH
ONBUILD RUN go env -w GOARCH=$TARGETARCH 

# GOARM ONBUILD
ONBUILD ARG TARGETVARIANT
ONBUILD RUN go env -w GOARM=${TARGETVARIANT##*v}