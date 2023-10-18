FROM redis

RUN mkdir -p /redis

WORKDIR /redis

COPY sentinel.conf .
COPY entrypoint.sh /usr/local/bin/

RUN chown redis:redis /redis/* && \
    chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["entrypoint.sh"]
