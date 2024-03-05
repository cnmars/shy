FROM --platform=$BUILDPLATFORM golang:alpine AS build-server
WORKDIR /app
COPY / /app
ARG TARGETOS
ARG TARGETARCH
WORKDIR /app/app
RUN set -ex \
    && GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 go build -o shy -trimpath -ldflags "-s -w" main.go

FROM --platform=${TARGETPLATFORM} alpine:latest
WORKDIR /shy
COPY --from=build-server /app/app/shy ./
COPY --from=build-server /app/scripts/config.yaml ./

VOLUME ["/shy"]

ENV LANG C.UTF-8
ENTRYPOINT [ "/shy/shy" ]