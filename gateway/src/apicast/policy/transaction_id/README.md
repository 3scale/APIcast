# APICast Transaction-ID

## Description

When enabled this policy adds a new header with unique ID to all of the request processed by APIcast. The unique ID header can also be included in the response to the client.

If the header is empty or non-existent, this policy will generate a UUID as the value of the user-defined header name

If a header with the same name is already present in the client request or upstream response, the policy will not modify it.

## Example configuration

* Add request unique ID
```
"policy_chain": [
    {
        "name": "transaction_id",
        "configuration": {
            "header_name": "X-Transaction-ID"
        },
        "version": "builtin",
    },
    {
      "name": "apicast.policy.apicast"
    }
]
```

* Include the header in response
```
"policy_chain": [
    {
        "name": "transaction_id",
        "configuration": {
            "header_name": "X-Transaction-ID",
            "include_in_response": true
        },
        "version": "builtin",
    },
    {
      "name": "apicast.policy.apicast"
    }
]
```

* Use with Logging policy

```
"policy_chain": [
    {
        "name": "transaction_id",
        "configuration": {
            "header_name": "X-Transaction-ID"
        },
        "version": "builtin",
    },
    {
      "name": "apicast.policy.logging",
      "configuration": {
        "enable_access_logs": false,
        "custom_logging": "\"{{request}}\" to service {{service.id}} and {{service.name}} with ID {{req.headers.X-Transaction-ID}}",
      }
    }
]
```
