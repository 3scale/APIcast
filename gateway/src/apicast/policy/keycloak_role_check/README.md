# Keycloak Role Check Policy

## Examples

- When you want to allow those who have the realm role `role1` to access `/resource1`.

  ```json
  {
    "scopes": [
      {
        "realm_roles": [ { "name": "role1" } ],
        "resource": "/resource1"
      }
    ]
  }
  ```

- When you want to allow those who have the client `client1`'s role `role1` to access `/resource1`.

  ```json
  {
    "scopes": [
      {
        "client_roles": [ { "name": "role1", "client": "client1" } ],
        "resource": "/resource1"
      }
    ]
  }
  ```

- When you want to allow those who don't have the realm role `role1` to access `/resource1`. Specify the `"blacklist"`.

  ```json
  {
    "scopes": [
      {
        "realm_roles": [ { "name": "role1" } ],
        "resource": "/resource1"
      }
    ],
    "type": "blacklist"
  }
  ```

- When you want to allow those who have the realm role `role1` and `role2` to access `/resource1`. Specity the roles in the `"realm_roles"`.

  ```json
  {
    "scopes": [
      {
        "realm_roles": [ { "name": "role1" }, { "name": "role2" } ],
        "resource": "/resource1"
      }
    ]
  }
  ```

- When you want to allow those who have the realm role `role1` or `role2` to access `/resource1`. Specify the scope for each role.

  ```json
  {
    "scopes": [
      { "realm_roles": [ { "name": "role1" } ], "resource": "/resource1" },
      { "realm_roles": [ { "name": "role2" } ], "resource": "/resource1" }
    ]
  }
  ```

- When you want to allow those who have the client role `role1` of the application client (the recipient of the access token) to access `/resource1`. Use the `"liquid"` to specify the JWT information to the `"client"`.

  ```json
  {
    "scopes": [
      {
        "client_roles": [ { "name": "role1", "client": "{{ jwt.aud }}", "client_type": "liquid" } ],
        "resource": "/resource1"
      }
    ]
  }
  ```

- When you want to allow those who have the client role including the client ID of the application client (the recipient of the access token) to access `/resource1`. Use the `"liquid"` to specify the JWT information to the `"name"` of the client role.

  ```json
  {
    "scopes": [
      {
        "client_roles": [ { "name": "role_{{ jwt.aud }}", "name_type": "liquid", "client": "client1" } ],
        "resource": "/resource1"
      }
    ]
  }
  ```

- When you want to allow those who have who have the client `client1`'s role `role1` to access the resource including the application client ID. Use the `"liquid"` to specify the JWT information to the `"resource"`.

  ```json
  {
    "scopes": [
      {
        "client_roles": [ { "name": "role1", "client": "client1" } ],
        "resource": "/resource_{{ jwt.aud }}", "resource_type": "liquid"
      }
    ]
  }
  ```

- When you want to allow those who have the realm role `role1` to access `/resource1` and only methods GET and POST.

  ```json
  {
    "scopes": [
      {
        "realm_roles": [ { "name": "role1" } ],
        "resource": "/resource1",
        "methods": ["GET", "POST"]
      }
    ]
  }
  ```

## `no_match` option

By default, when a request does not match any configured resource, the policy applies its type's default posture: a `whitelist` denies the request, a `blacklist` allows it. The `no_match` option overrides this behaviour independently of `type`.

| `no_match` value | Behaviour on unmatched resource |
|---|---|
| `type_defined` (default) | Follows `type`: whitelist denies, blacklist allows |
| `deny` | Always denies |
| `allow` | Always allows |

- When you want to protect only specific paths with a role check and leave all other paths open (scoped whitelist). Set `no_match` to `"allow"`.

  ```json
  {
    "scopes": [
      {
        "realm_roles": [ { "name": "admin" } ],
        "resource": "/admin"
      }
    ],
    "no_match": "allow"
  }
  ```

  Requests to `/admin` require the `admin` realm role. Requests to any other path are allowed regardless of roles.

- When you want to block role-holders from specific paths and also deny access to any path not explicitly listed. Set `type` to `"blacklist"` and `no_match` to `"deny"`.

  ```json
  {
    "scopes": [
      {
        "realm_roles": [ { "name": "restricted_role" } ],
        "resource": "/sensitive"
      }
    ],
    "type": "blacklist",
    "no_match": "deny"
  }
  ```

  Requests to `/sensitive` are denied if the token contains `restricted_role`. Requests to any other path are also denied.
