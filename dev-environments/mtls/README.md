# Making APIcast listen on HTTPS

## Create the SSL Certificates

```sh
make certs
```

## Prepare apicast-config.json

```sh
make template
```

## Run the gateway

Running local `apicast-test` docker image

```sh
make gateway
```

Running custom apicast image

```sh
make gateway IMAGE_NAME=quay.io/3scale/apicast:latest
```

## Testing CRL

Send request with valid cert

```
curl --resolve example.com:8443:127.0.0.1 -H "Host: crl.example.com" --cacert cert/rootCA.cert.pem --cert cert/client-chain.cert.pem --key cert/client.key.pem "https://example.com:8443/?user_key=123" --http1.1 -v
```

Request with revoked cert

```sh
curl --resolve example.com:8443:127.0.0.1 -H "Host: crl.example.com" --cacert cert/rootCA.cert.pem --cert cert/revoked_client-chain.cert.pem --key cert/revoked_client.key.pem "https://example.com:8443/?user_key=123" --http1.1 -v
```

## Testing OCSP

Send request with valid cert

```
curl --resolve example.com:8443:127.0.0.1 -H "Host: ocsp.example.com" --cacert cert/rootCA.cert.pem --cert cert/client-chain.cert.pem --key cert/client.key.pem "https://example.com:8443/?user_key=123" --http1.1 -v
```

Request with revoked cert

```sh
curl --resolve example.com:8443:127.0.0.1 -H "Host: ocsp.example.com" --cacert cert/rootCA.cert.pem --cert cert/revoked_client-chain.cert.pem --key cert/revoked_client.key.pem "https://example.com:8443/?user_key=123" --http1.1 -v
```

## Clean env

```sh
make clean
```
