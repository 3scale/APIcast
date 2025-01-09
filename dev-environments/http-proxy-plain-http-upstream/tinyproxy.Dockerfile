FROM mirror.gcr.io/library/alpine:3

LABEL summary="Forward proxy based on tinyproxy for development purposes" \
      description="Forward proxy based on tinyproxy for development purposes" \
      io.k8s.description="Forward proxy based on tinyproxy for development purposes" \
      io.k8s.display-name="Forward Proxy (Tinyproxy)" \
      io.openshift.tags="tinyproxy, proxy" \
      maintainer="3scale-engineering@redhat.com"

RUN apk --no-cache add tinyproxy
ENTRYPOINT ["/usr/bin/tinyproxy"]
CMD ["-d"]
