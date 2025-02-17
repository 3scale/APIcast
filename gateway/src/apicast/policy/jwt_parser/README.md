# JWT Parser

JWT Parser is used to parse the JSON Web Token (JWT) in the `Authorization` header and stores it in the request context that can be shared with other policies.

If `required` flag is set to true and no JWT token is sent, APIcast will reject the request and send HTTP ``WWW-Authenticate`` response header.
If `required` flag is set to true and no JWT token is invalid, APIcast will also reject the request.

NOTE: Not compatible with OIDC authentication mode. When this policy is added to a service configured with OIDC authentication mode, APIcast will print a warning about the incompatibility and ignore the policy.

## Example usage

With `JWT Claim Check` policy

```
"policy_chain": [
  {
    "name": "apicast.policy.jwt_parser",
    "configuration": {
      "issuer_endpoint": "http://red_hat_single_sign-on/auth/realms/foo",
    }
  },
  {
    "name": "apicast.policy.jwt_claim_check",
    "configuration": {
      "error_message": "Invalid JWT check",
      "rules": [
        {
            "operations": [
                {"op": "==", "jwt_claim": "role", "jwt_claim_type": "plain", "value": "admin"}
            ],
            "combine_op":"and",
            "methods": ["GET"],
            "resource": "/resource",
            "resource_type": "plain"
        }
      ]
    }
  }
]
```

With `Keycloak Role Check` policy

```
"policy_chain": [
  {
    "name": "apicast.policy.jwt_parser",
    "configuration": {
      "issuer_endpoint": "http://red_hat_single_sign-on/auth/realms/foo",
      "required": true
    }
  },
  {
    "name": "apicast.policy.keycloak_role_check",
    "configuration": {
      "scopes": [
        {
          "realm_roles": [ { "name": "foo" } ],
          "resource": "/confidential"
        }
      ]
    }
  },
]
```
