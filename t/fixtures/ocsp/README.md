
## Requirements
* cfssl - following steps require https://github.com/cloudflare/cfssl

## Steps
Initiate CA by creating root certificate pair:

```
cfssl gencert -initca cfssl/ca_csr.json | cfssljson -bare ca
```

Continue with intermediate certificate pair for signing:

```
cfssl gencert -ca ca.pem -ca-key ca-key.pem -config=cfssl/cfssl_config.json -profile=intermediate cfssl/intermediate_ca_csr.json | cfssljson -bare intermediate_ca
```

Also create OCSP certificate pair to sign OCSP responses:

```
cfssl gencert -ca intermediate_ca.pem -ca-key intermediate_ca-key.pem -config=cfssl/cfssl_config.json -profile=ocsp cfssl/ocsp_csr.json | cfssljson -bare ocsp
```

Create a leaf certificate:

```
cfssl gencert -ca intermediate_ca.pem -ca-key intermediate_ca-key.pem -config cfssl/cfssl_config.json -profile server cfssl/leaf_csr.json | cfssljson -bare leaf
```

Create a client certificate:

```
cfssl gencert -ca intermediate_ca.pem -ca-key intermediate_ca-key.pem -config cfssl/cfssl_config.json -profile client cfssl/leaf_csr.json | cfssljson -bare client
```

Create an OCSP response for the certificate:

```
cfssl ocspsign -ca intermediate_ca.pem -responder ocsp.pem -responder-key ocsp-key.pem -cert leaf.pem -status good | cfssljson -bare ocsp-response-good
```

Bundle certificate to be installed at Nginx:

```
cat leaf.pem intermediate_ca.pem ca.pem > leaf-bundle.pem
```

Inspect OCSP response to see what is the Next Update:

```
openssl ocsp -text -no_cert_verify -respin t/cert/ocsp/cfssl/ocsp-response-good-response.der | grep "Next Update"
```

Create an OCSP response with revoked status for the certificate:

```
cfssl ocspsign -ca intermediate_ca.pem -responder ocsp.pem -responder-key ocsp-key.pem -cert leaf.pem -status revoked -reason 1 | cfssljson -bare ocsp-response-good
```
