FROM --platform=$BUILDPLATFORM alpine AS zig-env

ARG ZIG_VERSION=0.10.1

# setup zig
RUN apk add --no-cache tar xz minisign
ADD https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz /tmp/zig.tar.xz
ADD https://ziglang.org/download/0.10.1/zig-linux-x86_64-0.10.1.tar.xz.minisig /tmp/zig.tar.xz.minisign
RUN minisign -Vm /tmp/zig.tar.xz -x /tmp/zig.tar.xz.minisign -P RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U
RUN mkdir -p "/usr/local/bin/zig" && tar -Jxf /tmp/zig.tar.xz -C "/usr/local/bin/zig" --strip-components=1

# remove unnecessary files
RUN rm -R /usr/local/bin/zig/lib/libc/include/any-windows-any
RUN rm -R /usr/local/bin/zig/lib/libc/include/aarch64-macos.11-none
RUN rm -R /usr/local/bin/zig/lib/libc/include/aarch64-macos.12-none
RUN rm -R /usr/local/bin/zig/lib/libc/include/aarch64-macos.13-none
RUN rm -R /usr/local/bin/zig/lib/libc/include/any-macos-any
RUN rm -R /usr/local/bin/zig/lib/libc/include/any-macos.11-any
RUN rm -R /usr/local/bin/zig/lib/libc/include/any-macos.12-any
RUN rm -R /usr/local/bin/zig/lib/libc/include/any-macos.13-any
RUN rm -R /usr/local/bin/zig/doc

# build environment
FROM --platform=$BUILDPLATFORM golang:1-alpine

# fix vulnerabilities
RUN --mount=type=cache,target=/go/pkg \
    cd /usr/local/go/src && \
    go get -u golang.org/x/sys golang.org/x/net golang.org/x/text golang.org/x/crypto
RUN --mount=type=cache,target=/go/pkg \
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
    go install github.com/dosgo/zigtool/zigcpp@latest

# cleanup
RUN go clean -cache && \
    go clean -modcache

# set working directory
WORKDIR /go/src

# GOARCH ONBUILD
ONBUILD ARG TARGETARCH
ONBUILD RUN go env -w GOARCH=$TARGETARCH 

# GOARM ONBUILD
ONBUILD ARG TARGETVARIANT
ONBUILD RUN go env -w GOARM=${TARGETVARIANT##*v}