# Plain HTTP 1.1 upstream 3

APIcast <--> plain HTTP 1.1 upstream

APIcast configured with plain HTTP 1.1 upstream server equipped with traffic rely agent (socat)

Run `make plain-upstream-gateway IMAGE_NAME=quay.io/3scale/apicast:latest`


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

Traffic between APIcast and upstream can be inspected looking at logs from `upstream-rely` service

```
❯ docker compose -p apicast_build_0 logs upstream-rely
```
