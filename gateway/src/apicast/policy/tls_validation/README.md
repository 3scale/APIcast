# TLS Validation policy

This policy can validate TLS Client Certificate against a whitelist.

Whitelist expects PEM formatted CA or Client certificates.
It is not necessary to have the full certificate chain, just partial matches are allowed.
For example you can add to the whitelist just leaf client certificates without the whole bundle with a CA certificate.

## Configuration

For this policy to work, APIcast need to be setup to listen for TLS connection.

By default, during the TLS handshake, APIcast requests client certificates, but will not verify the certificate or terminate the request unless a TLS Validation Policy is in the chain. In most cases, the client not presenting a client certificate will not affect a service that does not have TLS Validation policy configured. The only exception is when a browser or front-end application uses the service. In this case, the browser will always prompt the user to choose a client certificate to send if they have any client certificates set up while accessing the service.

To work around this, set the environment variable `APICAST_HTTPS_VERIFY_CLIENT` to `off`. This instructs APIcast to request a client certificate only when the policy is in the chain.

NOTE: This policy is not compatible with `APICAST_PATH_ROUTING` or `APICAST_PATH_ROUTING_ONLY` when `APICAST_HTTPS_VERIFY_CLIENT` is set to `off`.

## Example

```
{
  "name": "apicast.policy.tls_validation",
  "configuration": {
    "whitelist": [
      { "pem_certificate": ""-----BEGIN CERTIFICATE----- XXXXXX -----END CERTIFICATE-----"}
    ]
  }
}
```
