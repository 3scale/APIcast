# PROXY with upstream using TLSv1.3

APIcast --> tiny proxy (connect to 443 but no cert installed) --> upstream (TLSv1.3)

APIcast configured with TLS upstream. TLS termination endpoint is socat.

APicast starts SSL tunnel (via HTTP Connect method) against proxy to access upstream configured with TLSv1.3

* GET request
```
# you need container name of the gateway
APICAST_IP=$(docker inspect apicast_build_0-gateway-run-3b16b962fa2a | yq e -P '.[0].NetworkSettings.Networks.apicast_build_0_default.IPAddress' -)
curl -v -H "Host: get" http://${APICAST_IP}:8080/?user_key=foo
```

* POST request
```
# you need container name of the gateway
APICAST_IP=$(docker inspect apicast_build_0-gateway-run-3b16b962fa2a | yq e -P '.[0].NetworkSettings.Networks.apicast_build_0_default.IPAddress' -)
curl -v -X POST -H "Host: post" http://${APICAST_IP}:8080/?user_key=foo
```

NOTE: pem file creation
```
// generate a private key;
$ openssl genrsa -out server.key 1024
// generate a self signed cert:
$ openssl req -new -key server.key -x509 -days 3653 -out server.crt
//     enter fields... (may all be empty when cert is only used privately)
// generate the pem file:
$ cat server.key server.crt >server.pem
```

Traffic between the proxy and upstream can be inspected looking at logs from `upstream-rely` service

```
❯ docker compose -p apicast_build_0 logs tls.termination
```
