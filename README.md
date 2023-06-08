# ziggoimg

Cross compilation image for Linux GO application using ZIG as CC

## Example Dockerfile

```YAML
# build stage
FROM --platform=$BUILDPLATFORM ghcr.io/kwitsch/ziggoimg AS build

# set working directory
WORKDIR /go/src

# download packages
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg \
    go mod download

# add source
COPY . .

# compile application
RUN --mount=type=bind,target=. \
    --mount=type=cache,target=/root/.cache/go-build \ 
    --mount=type=cache,target=/go/pkg \
    go build \
    -v \
    -o /bin/ctest .

# release stage
FROM scratch

# copy application
COPY --from=build /bin/ctest /app/ctest

# set entry point
ENTRYPOINT ["/bin/ctest"]
```
