use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";
$ENV{TEST_NGINX_HTML_DIR} ||= "$Test::Nginx::Util::ServRoot/html";
$ENV{APICAST_POLICY_LOAD_PATH} = 't/fixtures/policies';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: authentication credentials missing
The message is configurable as well as the status.
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy" : {
        "error_auth_missing": "credentials missing!",
        "error_status_auth_missing": 401
      }
    }
  ]
}
--- request
GET / 
--- response_body chomp
credentials missing!
--- error_code: 401
--- no_error_log
[error]


=== TEST 2: credentials missing default error
There are defaults defined for the error message, the content-type, and the
status code (401).
--- configuration
{
  "services" : [
    {
      "backend_version": 2
    }
  ]
}
--- request
GET /?app_key=42
--- response_headers 
Content-Type: text/plain; charset=utf-8
--- response_body chomp
Authentication parameters missing
--- error_code: 401
--- no_error_log
[error]


=== TEST 3: authentication (part of) credentials missing configurable error
The message is configurable as well as the status.
--- configuration
{
  "services" : [
    {
      "backend_version": 2,
      "proxy" : {
        "error_auth_missing" : "credentials missing!",
        "error_status_auth_missing" : 401
      }
    }
  ]
}
--- request
GET /?app_key=42
--- response_body chomp
credentials missing!
--- error_code: 401
--- no_error_log
[error]


=== TEST 4: no mapping rules matched default error
There are defaults defined for the error message, the content-type, and the
status code (404).
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1
    }
  ]
}
--- request
GET /?user_key=value
--- response_body chomp
No Mapping Rule matched
--- response_headers
Content-Type: text/plain; charset=utf-8
--- error_code: 404
--- no_error_log
[error]


=== TEST 5: no mapping rules matched configurable error
The message is configurable and status also.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "proxy": {
        "error_no_match": "no mapping rules!",
        "error_status_no_match": 412 
      }
    }
  ]
}
--- request
GET /?user_key=value
--- response_body chomp
no mapping rules!
--- error_code: 412
--- no_error_log
[error]


=== TEST 6: authentication credentials invalid default error
There are defaults defined for the error message, the content-type, and the
status code (403).
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    deny all;
  }
--- upstream
  location /api-backend/ {
     echo 'yay, api backend!';
  }
--- request
GET /?user_key=value
--- response_headers
Content-Type: text/plain; charset=utf-8
--- response_body chomp
Authentication failed
--- error_code: 403


=== TEST 7: authentication credentials invalid configurable error
The message is configurable and default status is 403.
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy": {
        "error_auth_failed" : "credentials invalid!",
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "error_status_auth_failed": 402,
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    deny all;
  }
--- upstream
  location /api-backend/ {
     echo 'yay, api backend!';
  }
--- request
GET /?user_key=value
--- response_body chomp
credentials invalid!
--- error_code: 402

=== TEST 8: api backend gets the request
It asks backend and then forwards the request to the api.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 2} 
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
        require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- upstream
  location /api-backend/ {
    echo 'yay, api backend: $http_host'; 
  }
--- request
GET /?user_key=value
--- response_body env
yay, api backend: test:$TEST_NGINX_SERVER_PORT
--- error_code: 200
--- error_log
apicast cache miss key: 42:value:usage%5Bhits%5D=2
--- no_error_log
[error]


=== TEST 9: mapping rule with fixed value is mandatory
When mapping rule has a parameter with fixed value it has to be matched.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "proxy": {
        "error_no_match": "no mapping rules matched!",
        "error_status_no_match": 412,
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/foo?bar=baz", "querystring_parameters": {"bar": "baz"}, "http_method" : "GET", "metric_system_name" : "bar", "delta" : 1} 
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) } 
  }
--- request
GET /foo?bar=foo&user_key=somekey
--- response_body chomp
no mapping rules matched!
--- error_code: 412
--- no_error_log
[error]


=== TEST 10: mapping rule with fixed value is mandatory
When mapping rule has a parameter with fixed value it has to be matched.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "my-token",
      "proxy": {
        "error_no_match": "no mapping rules matched!",
        "error_status_no_match": 412,
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/foo?bar=baz", "querystring_parameters": {"bar": "baz"}, "http_method" : "GET", "metric_system_name" : "bar", "delta" : 1} 
        ]
      }
    }
  ]
}
--- upstream
  location /api-backend/ {
     echo 'yay, api backend!';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) } 
  }
--- request
GET /foo?bar=baz&user_key=somekey
--- more_headers
X-3scale-Debug: my-token
--- response_body
yay, api backend!
--- no_error_log
[error]


=== TEST 11: mapping rule with variable value is required to be sent
When mapping rule has a parameter with variable value it has to exist.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "my-token",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/foo?bar={baz}", "querystring_parameters": {"bar": "{baz}"}, "http_method" : "GET", "metric_system_name" : "bar", "delta" : 3} 
        ]
      }
    }
  ]
}
--- upstream
  location /api-backend/ {
     echo 'yay, api backend!';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) } 
  }
--- request
GET /foo?bar={foo}&user_key=somekey
--- more_headers
X-3scale-Debug: my-token
--- response_body
yay, api backend!
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?bar={baz}
X-3scale-usage: usage%5Bbar%5D=3
--- no_error_log
[error]


=== TEST 12: https api backend works
--- ssl random_port
--- configuration random_port env
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "proxy": {
        "api_backend": "https://test:$TEST_NGINX_RANDOM_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ]
      }
    }
  ]
}
--- upstream env
  listen $TEST_NGINX_RANDOM_PORT ssl;
  ssl_certificate $TEST_NGINX_HTML_DIR/server.crt;
  ssl_certificate_key $TEST_NGINX_HTML_DIR/server.key;
  
  location /api-backend/ {
     echo 'yay, api backend!';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) } 
  }
--- request
GET /test?user_key=foo
--- response_body
yay, api backend!
--- error_code: 200
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIB0DCCAXegAwIBAgIJAISY+WDXX2w5MAoGCCqGSM49BAMCMEUxCzAJBgNVBAYT
AkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
aXRzIFB0eSBMdGQwHhcNMTYxMjIzMDg1MDExWhcNMjYxMjIxMDg1MDExWjBFMQsw
CQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhkmo
6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1cbx0wVEzbYK5wRb7U
iWhvvvYDltIzsD75vqNQME4wHQYDVR0OBBYEFOBBS7ZF8Km2wGuLNoXFAcj0Tz1D
MB8GA1UdIwQYMBaAFOBBS7ZF8Km2wGuLNoXFAcj0Tz1DMAwGA1UdEwQFMAMBAf8w
CgYIKoZIzj0EAwIDRwAwRAIgZ54vooA5Eb91XmhsIBbp12u7cg1qYXNuSh8zih2g
QWUCIGTHhoBXUzsEbVh302fg7bfRKPCi/mcPfpFICwrmoooh
-----END CERTIFICATE-----
>>> server.key
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIFCV3VwLEFKz9+yTR5vzonmLPYO/fUvZiMVU1Hb11nN8oAoGCCqGSM49
AwEHoUQDQgAEhkmo6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1c
bx0wVEzbYK5wRb7UiWhvvvYDltIzsD75vg==
-----END EC PRIVATE KEY-----
--- no_error_log
[error]


=== TEST 13: print warning on duplicate service hosts
So when booting it can be immediately known that some of them won't work.
--- configuration
{
  "services" : [
  { "id" : 1, "proxy" : { "hosts" : [ "foo", "bar" ] } },
  { "id" : 2, "proxy" : { "hosts" : [ "foo", "daz" ] } },
  { "id" : 1, "proxy" : { "hosts" : [ "foo", "fee" ] } }
  ]
}
--- request
GET /
--- error_code: 404
--- log_level: warn
--- grep_error_log eval: qr/host .+? for service .? already defined by service [^,\s]+/
--- grep_error_log_out
host foo for service 2 already defined by service 1
--- no_error_log
[error]


=== TEST 14: print message that service was added to the configuration
Including its host so it is easy to see that configuration was loaded.
--- configuration
{
  "services" : [
  { "id" : 1, "proxy" : { "hosts" : [ "foo", "bar" ] } },
  { "id" : 2, "proxy" : { "hosts" : [ "baz", "daz" ] } }
  ]
}
--- request
GET /
--- error_code: 404
--- log_level: info
--- error_log
added service 1 configuration with hosts: foo, bar
added service 2 configuration with hosts: baz, daz
--- no_error_log
[error]


=== TEST 15: return headers with debugging info
When X-3scale-Debug header has value of the backend authentication
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "service-token",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 2} 
        ]
      }
    }
  ]
}
--- upstream
  location / {
     echo 'yay, api backend!';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) } 
  }
--- request
GET /?user_key=somekey
--- more_headers
X-3scale-Debug: service-token
--- response_body
yay, api backend!
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /
X-3scale-usage: usage%5Bhits%5D=2
--- no_error_log
[error]


=== TEST 16: uses endpoint host as Host header
when connecting to the backend
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value" : "service-token",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 2} 
        ]
      }
    }
  ]
}
--- upstream
  location / {
     echo 'yay, api backend!';
  }
--- backend
  location /transactions/authrep.xml {
     content_by_lua_block {
       if ngx.var.host == 'test_backend' then
         ngx.exit(200)
       else
         ngx.log(ngx.ERR, 'invalid host: ', ngx.var.host)
         ngx.exit(404)
       end
     }
  }
--- request
GET /?user_key=somekey
--- response_body
yay, api backend!
--- error_code: 200
--- no_error_log
[error]


=== TEST 17: invalid service
The message is configurable and default status is 404.
--- configuration
{}
--- request
GET /?user_key=value
--- error_code: 404
--- no_error_log
[error]


=== TEST 18: default limits exceeded error
There are defaults defined for the error message, the content-type, and the status code (429).
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ]
      }
    }
  ]
}
--- upstream
  location / {
     echo 'yay, api backend!';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      if ngx.var['http_3scale_options'] == 'rejection_reason_header=1&limit_headers=1&no_body=1' then
        ngx.header['3scale-rejection-reason'] = 'limits_exceeded';
      end
      ngx.status = 409;
      ngx.exit(ngx.HTTP_OK);
    }
  }
--- request
GET /?user_key=somekey
--- response_headers
Content-Type: text/plain; charset=utf-8
--- response_body chomp
Limits exceeded
--- error_code: 429
--- no_error_log
[error]


=== TEST 19: configurable limits exceeded error
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy": {
        "error_limits_exceeded" : "limits exceeded!",
        "error_status_limits_exceeded": 402,
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ]
      }
    }
  ]
}
--- upstream
  location / {
     echo 'yay, api backend!';
  }
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      if ngx.var['http_3scale_options'] == 'rejection_reason_header=1&limit_headers=1&no_body=1' then
        ngx.header['3scale-rejection-reason'] = 'limits_exceeded';
      end
      ngx.status = 409;
      ngx.exit(ngx.HTTP_OK);
    }
  }
--- request
GET /?user_key=somekey
--- response_body chomp
limits exceeded!
--- error_code: 402
--- no_error_log
[error]


=== TEST 20: Credentials in large POST body
POST bodies larger than 'client_body_buffer_size' are written to a temp file,
and we ignore them. That means that credentials stored in the body are not
taken into account.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "error_auth_missing": "credentials missing!",
        "error_status_auth_missing": 401,
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "POST", "metric_system_name" : "hits", "delta" : 2} 
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      -- Notice that the user_key sent in the body does not appear here.
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- request eval
"POST /
user_key=value-".( "1" x 16 x 1024)
--- response_body chomp
credentials missing!
--- error_code: 401
--- no_error_log
[error]


=== TEST 21: returns 'Retry-After' header when rate-limited by 3scale backend
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ]
      }
    }
  ]
}
--- upstream
location /api-backend/ {
  echo "yay, api backend!";
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        local expected_3scale_opts = 'rejection_reason_header=1&limit_headers=1&no_body=1'
        if ngx.var['http_3scale_options'] == expected_3scale_opts then
          ngx.header['3scale-rejection-reason'] = 'limits_exceeded';
          ngx.header['3scale-limit-reset'] = 60
        end
        ngx.status = 409;
        ngx.exit(ngx.HTTP_OK);
    }
  }
--- request 
GET /?user_key=value
--- response_headers
Retry-After: 60
--- response_body chomp
Limits exceeded
--- error_code: 429
--- no_error_log
[error]


=== TEST 22: APIcast placed after a policy that denies the request in rewrite()
This test checks that APIcast does not call authrep.
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ],
        "policy_chain" : [
          {
            "name" : "deny",
            "version" : "1.0.0",
            "configuration" : {"phase" : "rewrite"}
          },
          { "name" : "apicast.policy.apicast" }
        ] 
      }
    }
  ]
}
--- upstream
location /api-backend/ {
  echo "yay, api backend!";
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
       error('APIcast called authrep, but it should not have') 
    }
  }
--- request 
GET /?user_key=value
--- error_code: 403
--- no_error_log
[error]


=== TEST 23: APIcast placed after a policy that denies the request in access()
This test checks that APIcast does not call authrep.
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ],
        "policy_chain" : [
          {
            "name" : "deny",
            "version" : "1.0.0",
            "configuration" : {"phase" : "access"}
          },
          { "name" : "apicast.policy.apicast" }
        ] 
      }
    }
  ]
}
--- upstream
location /api-backend/ {
  echo "yay, api backend!";
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
       error('APIcast called authrep, but it should not have') 
    }
  }
--- request 
GET /?user_key=value
--- error_code: 403
--- no_error_log
[error]


=== TEST 24: returns "authorization failed" instead of "limits exceeded" for disabled metrics
"Disabled metrics" are those that have a limit of 0 in the 3scale backend.
--- configuration
{
  "services" : [
    {
      "backend_version": 1,
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "proxy_rules": [
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ]
      }
    }
  ]
}
--- upstream
location /api-backend/ {
  echo "yay, api backend!";
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected_3scale_opts = 'rejection_reason_header=1&limit_headers=1&no_body=1'
      require('luassert').same(ngx.var['http_3scale_options'], expected_3scale_opts)

      ngx.header['3scale-rejection-reason'] = 'limits_exceeded';
      ngx.header['3scale-limit-reset'] = 60;
      ngx.header['3scale-limit-max-value'] = 0;

      ngx.status = 409;
      ngx.exit(ngx.HTTP_OK);
    }
  }
--- request 
GET /?user_key=value
--- response_body chomp
Authentication failed
--- error_code: 403
--- no_error_log
[error]

