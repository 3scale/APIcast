# APICast CORS Policy

This policy allows to enable CORS Headers for the service.

## Example configuration

```
{
  "name": "cors",
  "version": "builtin",
  "configuration": {
    "allow_headers": [
      "App-Id", "App-Key",
      "Content-Type", "Accept"
    ],
    "allow_credentials": true,
    "allow_methods": [
      "GET", "POST"
    ],
    "allow_origin": "https://example.com",
    "max_age" : 200
  }
```

## Recommended configuration

- Setting `allow_origin` to blank will enable any origin for `Cross request` on the service.
- If used alongside with `APICAST_PATH_ROUTING` the policy must be enabled for every service that share the same host name.
