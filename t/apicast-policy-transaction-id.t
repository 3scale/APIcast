use lib 't';
use Test::APIcast::Blackbox 'no_plan';

# Test::Nginx does not allow to grep access logs, so we redirect them to
# stderr to be able to use "grep_error_log" by setting APICAST_ACCESS_LOG_FILE
$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";

run_tests();

__DATA__

=== TEST 1: Enables transaction-id policy and generate uuid if the header is not
present in the client request
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.transaction_id",
            "configuration": {
                "header_name": "X-Transaction-ID"
            }
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}

--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
       local assert = require('luassert')
       local uuid = require('resty.jit-uuid')
       assert.is_true(uuid.is_valid(ngx.req.get_headers()['X-Transaction-ID']))
     }
  }
--- request
GET /?user_key=value
--- error_code: 200
--- no_error_log
[error]



=== TEST 2: Respect header from the original request
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.transaction_id",
            "configuration": {
                "header_name": "x-transaction-id"
            }
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}

--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
       local assert = require('luassert')
       local id = ngx.req.get_headers()['X-Transaction-ID']
       assert.equal('blah', id)
     }
  }
--- more_headers
X-Transaction-ID: blah
--- request
GET /?user_key=value
--- error_code: 200
--- no_error_log
[error]



=== TEST 3: Also set the response header
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.transaction_id",
            "configuration": {
                "header_name": "x-transaction-id",
                "include_in_response": true
            }
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}

--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
       local assert = require('luassert')
       local id = ngx.req.get_headers()['X-Transaction-ID']
       assert.equal('blah', id)
     }
  }
--- more_headers
X-Transaction-ID: blah
--- request
GET /?user_key=value
--- response_headers
X-Transaction-ID: blah
--- error_code: 200
--- no_error_log
[error]



=== TEST 4: respect the response header from upstream
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.transaction_id",
            "configuration": {
                "header_name": "x-transaction-id",
                "include_in_response": true
            }
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}

--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
       local assert = require('luassert')
       ngx.header['X-Transaction-ID'] = "foo"
     }
  }
--- more_headers
X-Transaction-ID: blah
--- request
GET /?user_key=value
--- response_headers
X-Transaction-ID: foo
--- error_code: 200
--- no_error_log
[error]



=== TEST 5: work with Logging policy and custom access log format
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.transaction_id",
            "configuration": {
                "header_name": "x-transaction-id",
                "include_in_response": true
            }
          },
          {
            "name": "apicast.policy.logging",
            "configuration": {
                "custom_logging": "Status::{{ status }} Request-Transaction-ID::{{ req.headers.X-Transaction-ID }} Response-Transaction-ID::{{ resp.headers.X-Transaction-ID }}"
            }
          },
          {
            "name": "apicast.policy.upstream",
            "configuration":
              {
                "rules": [ { "regex": "/", "url": "http://echo" } ]
              }
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
        ngx.say("yay")
     }
  }
--- more_headers
X-Transaction-ID: blah
--- request
GET /?user_key=value
--- error_code: 200
--- error_log eval
[ qr/^Status\:\:200 Request-Transaction-ID\:\:blah Response-Transaction-ID\:\:blah/ ]
--- no_error_log eval
[qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/]
