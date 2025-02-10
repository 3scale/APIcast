FROM registry.access.redhat.com/ubi8/go-toolset:1.13.4 as builder

WORKDIR /workspace

RUN cd /tmp \
    && curl -fSL https://github.com/kalmhq/echoserver/archive/refs/tags/v0.1.1.tar.gz -o echoserver-v0.1.1.tar.gz \
    && tar xzf echoserver-v0.1.1.tar.gz \
    && cd echoserver-0.1.1 \
    && go mod download \
    && GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o server . \
    && cp server /workspace \
    && cp default.key /workspace \
    && cp default.pem /workspace

FROM mirror.gcr.io/library/alpine
RUN apk update && apk add --no-cache curl
WORKDIR /workspace
# Collect binaries and assets
RUN mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
COPY --from=builder /workspace/server .
COPY --from=builder /workspace/default.key .
COPY --from=builder /workspace/default.pem .
CMD /workspace/server
