FROM mirror.gcr.io/library/alpine:3

RUN apk --no-cache add openssl

COPY cert /cert

COPY docker-entrypoint.sh docker-entrypoint.sh
EXPOSE 2560
ENTRYPOINT [ "/bin/sh", "docker-entrypoint.sh" ]
