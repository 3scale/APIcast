use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";
$ENV{TEST_NGINX_HTML_DIR} ||= "$Test::Nginx::Util::ServRoot/html";
$ENV{APICAST_REPORTING_THREADS} = 1;

check_accum_error_log();
repeat_each(1);
run_tests();

__DATA__

=== TEST 1: api backend gets the request
It asks backend and then forwards the request to the api.
--- configuration
{
    "services": [
      {
        "id": 42,
        "backend_version": 1,
        "backend_authentication_type": "service_token",
        "backend_authentication_value": "token-value",
        "proxy": {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
            "proxy_rules": [
                { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 2 }
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
--- pipelined_requests eval
["GET /?user_key=value","GET /?user_key=value"]
--- response_body env eval
["yay, api backend: test:$TEST_NGINX_SERVER_PORT\x{0a}","yay, api backend: test:$TEST_NGINX_SERVER_PORT\x{0a}"]
--- error_code eval
["200","200"]
--- no_error_log
[error]


=== TEST 2: https api backend works
with async background reporting
--- ssl random_port
--- env random_port eval
(
  'BACKEND_ENDPOINT_OVERRIDE' => "https://test_backend:$ENV{TEST_NGINX_RANDOM_PORT}"
)
--- configuration random_port env
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
            { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1} 
        ]
      }
    }
  ]
}
--- upstream
  location /api-backend/ {
     echo 'yay, api backend!';
  }
--- backend random_port env
  listen $TEST_NGINX_RANDOM_PORT ssl;
  ssl_certificate $TEST_NGINX_HTML_DIR/server.crt;
  ssl_certificate_key $TEST_NGINX_HTML_DIR/server.key;
  
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=1&user_key=foo"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
      ngx.exit(200)
    }
  }
--- pipelined_requests eval
["GET /test?user_key=foo","GET /test?user_key=foo"]
--- response_body eval
["yay, api backend!\x{0a}","yay, api backend!\x{0a}"]
--- error_code eval 
["200","200"]
--- wait: 3
--- error_log
reporting to backend asynchronously
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


=== TEST 3: uses endpoint host as Host header
when connecting to the backend
--- configuration
{
    "services": [
      {
        "id": 42,
        "backend_version": 1,
        "backend_authentication_type": "service_token",
        "backend_authentication_value": "token-value",
        "proxy": {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
            "proxy_rules": [
                { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 2 }
            ]
        }
      }
    ]
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
--- upstream
location /api-backend/ {
  echo 'yay, api backend';
}
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}"]
--- pipelined_requests eval
["GET /?user_key=foo","GET /?user_key=foo"]
--- error_code eval
["200","200"]
--- error_log env eval
[
  qr/backend client uri\: http\:\/\/test_backend\:$TEST_NGINX_SERVER_PORT\/transactions\/authrep.xml\?.*?(service_id=42).*? ok\: true status\: 200/,
  qr/backend client uri\: http\:\/\/test_backend\:$TEST_NGINX_SERVER_PORT\/transactions\/authrep.xml\?.*?(service_token=token\-value).*? ok\: true status\: 200/,
  qr/backend client uri\: http\:\/\/test_backend\:$TEST_NGINX_SERVER_PORT\/transactions\/authrep.xml\?.*?(user_key=foo).*? ok\: true status\: 200/,
  qr/backend client uri\: http\:\/\/test_backend\:$TEST_NGINX_SERVER_PORT\/transactions\/authrep.xml\?.*?(usage%5Bhits%5D=2).*? ok\: true status\: 200/,
  qr/reporting to backend asynchronously/
]
--- wait: 3
--- no_error_log
[error]

