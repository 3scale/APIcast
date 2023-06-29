# upstream using TLSv1.3

APIcast --> upstream (TLSv1.3)

APIcast configured with TLS upstream. TLS termination endpoint is socat.

Run `make upstream-tls-gateway`

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

```
curl -v -H "Host: one" http://${APICAST_IP}:8080/?user_key=foo
```

NOTE: using `one.upstream` as upstream hostname becase when APIcast resolves `upstream` it returns `0.0.0.1`
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
