# FAPI Policy

## Description

The FAPI policy supports various features of the Financial-grade API (FAPI) standard.

* [FAPI 1.0 Baseline Profile](https://openid.net/specs/openid-financial-api-part-1-1_0.html)
* [FAPI 1.0 Advance Profile](https://openid.net/specs/openid-financial-api-part-2-1_0.html)

## Example configuration

FAPI policy set the response header `x-fapi-interaction-id` to the value received from the corresponding FAPI client request header or to a RFC4122 UUID value if the request header was not provided.

```
"policy_chain": [
    { "name": "apicast.policy.fapi", "configuration": {} },
    {
      "name": "apicast.policy.apicast"
    }
]
```
### Log the value of x-fapi-interaction-id header

```
"policy_chain": [
   { "name": "apicast.policy.fapi", "configuration": {} },
   {
     "name": "apicast.policy.logging",
     "configuration": {
       "enable_access_logs": false,
       "custom_logging": "[{{time_local}}] {{host}}:{{server_port}} {{remote_addr}}:{{remote_port}} x-fapi-interaction-id: {{resp.headers.x-fapi-interaction-id}} \"{{request}}\"  {{status}} {{body_bytes_sent}} ({{request_time}}) {{post_action_impact}} ",
     }
   }
   { "name": "apicast.policy.apicast" }
]
```

### Validate x-fapi-customer-ip-address header
Validate requests with a x-fapi-customer-ip-address header containing a valid IPv4 or IPv6 address

```
"policy_chain": [
    {
      "name": "apicast.policy.fapi",
      "configuration": {
        "validate_x_fapi_customer_ip_address": true
      }
    },
    {
      "name": "apicast.policy.apicast"
    }
]
```

### Validate certificate-bound access tokens

Certificate-bound access tokens, as defined in [RFC 8705](https://datatracker.ietf.org/doc/html/rfc8705), enhance security by linking tokens to clients, thereby verifying the sender's authorization to access protected resources.

You'll need to:
* Configure an Identity Provider (IdP) such as Keycloak with mTLS and X.509 client certificate authentication.
* Configure the gateway to handle mTLS client certificate authentication.
* Enable `validate_oauth2_certificate_bound_access_token` in the FAPI plugin.

```
"policy_chain": [
    {
      "name": "apicast.policy.fapi",
      "configuration": {
        "validate_oauth2_certificate_bound_access_token": true
      }
    },
    {
      "name": "apicast.policy.apicast"
    }
]
```
