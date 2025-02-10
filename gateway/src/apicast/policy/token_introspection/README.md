# OAuth 2.0 Token Introspection

 The OAuth 2.0 Token Introspection Policy allows validating the JSON Web Token (JWT) used for services with the OpenID Connect (OIDC) authentication option using the Token Introspection Endpoint of the token issuer.

APIcast supports the following authentication types in the `auth_type` field to determine the Token Introspection Endpoint and the credentials APIcast uses when calling this endpoint:
* `use_3scale_oidc_issuer_endpoint`: APIcast uses the client credentials, Client ID, and Client Secret, as well as the Token Introspection Endpoint from the OIDC Issuer setting configured on the Service Integration page. APIcast discovers the Token Introspection Endpoint from the `token_introspection_endpoint` field. This field is located in the `.well-known/openid-configuration` endpoint that is returned by the OIDC issuer.
* `client_id+client_secret`: This option enables you to specify a different Token Introspection Endpoint. As well as the Client ID and Client Secret that APIcast uses to request token information.
* `client_secret_jwt`: This option uses `client_secret_jwt` method to request token information. Prior to a token information request, APIcast will prepare a new JWT authentication token and sign with the Client Secret using an HMAC SHA-256 algorithm. Then, APIcast will make a token information request with the generated JWT as the value for the `client_assertion` parameter.
* `private_key_jwt`: This option uses asymmetric key to request token information from the OIDC provider. Prior to a token information request, APIcast will prepare a new JWT authentication token and sign the token with the private key provided. Then, APIcast will make a token information request with the generated token as the value for the `client_assertion` parameter.

 The response of the Token Introspection Endpoint contains the active attribute. APIcast checks the value of this attribute. Depending on the value of the attribute, APIcast authorizes or rejects the call:
* `true`: The call is authorized.
* `false`: The call is rejected with the Authentication Failed error.

The policy enables caching of the tokens to avoid calling the Token Introspection Endpoint on every call for the same JWT token. To enable token caching for the Token Introspection Policy, set the `max_cached_tokens` field to a value between `0`, which disables the feature, and `10000`. Additionally, you can set a Time to Live (TTL) value from `1` to `3600` seconds for tokens in the `max_ttl_tokens` field. 

## Examples:

- With `use_3scale_oidc_issuer_endpoint`

```
{
  "name": "apicast.policy.token_introspection",
  "configuration": {
    "auth_type": "use_3scale_oidc_issuer_endpoint",
  }
}
```

- With `client_id+client_secret`

```
{
  "name": "apicast.policy.token_introspection",
  "configuration": {
    "auth_type": "client_id+client_secret",
    "client_id": "myclient",
    "client_secret": "mysecret",
    "introspection_url": "http://red_hat_single_sign-on/token/introspection"
  }
}
```

- With `client_secret_jwt`

```
{
  "name": "apicast.policy.token_introspection",
  "configuration": {
    "auth_type": "client_secret_jwt",
    "client_id": "myclient",
    "client_secret": "mysecret",
    "introspection_url": "http://red_hat_single_sign-on/token/introspection",
    "client_jwt_assertion_audience": "http://red_hat_single_sign-on/auth/realms/basic",
    "client_jwt_assertion_expires_in": 60
  }
}
```

- With `private_key_jwt`

```
{
  "name": "apicast.policy.token_introspection",
  "configuration": {
    "auth_type": "private_key_jwt",
    "client_id": "myclient",
    "introspection_url": "http://red_hat_single_sign-on/token/introspection",
    "client_jwt_assertion_audience": "http://red_hat_single_sign-on/auth/realms/basic",
    "client_jwt_assertion_expires_in": 60,
    "certificate_type": "embedded",
    "certificate": "data:application/x-x509-ca-cert;name=rsa.pem;base64,XXXXXXXXX"
  }
}
```
