use lib 't';
use Test::APIcast::Blackbox 'no_plan';
use Crypt::JWT qw(encode_jwt);

our $private_key = `cat t/fixtures/rsa.pem`;
our $public_key = `cat t/fixtures/rsa.pub`;

sub authorization_bearer_jwt (@) {
    my ($aud, $payload, $kid) = @_;

    my $jwt = encode_jwt(payload => {
        aud => $aud,
        sub => 'someone',
        iss => 'https://example.com/auth/realms/apicast',
        exp => time + 3600,
        %$payload,
    }, key => \$private_key, alg => 'RS256', extra_headers => { kid => $kid });

    return "Bearer $jwt";
}

run_tests();

__DATA__

=== TEST 1: Enables fapi policy inject x-fapi-interaction-id header to the response
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
            "name": "apicast.policy.fapi", "configuration": {}
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
        ngx.exit(200)
     }
  }
--- more_headers
x-fapi-interaction-id: abc
--- response_headers
x-fapi-interaction-id: abc
--- request
GET /?user_key=value
--- error_code: 200
--- no_error_log
[error]



=== TEST 2: When x-fapi-interaction-id exist in both request and response headers, always use
value from request
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
            "name": "apicast.policy.fapi"
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
       ngx.header['x-fapi-interaction-id'] = "blah"
       ngx.exit(200)
     }
  }
--- more_headers
x-fapi-interaction-id: abc
--- request
GET /?user_key=value
--- response_headers
x-fapi-interaction-id: abc
--- error_code: 200
--- no_error_log
[error]



=== TEST 3: Use x-fapi-interaction-id header from upstream response
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
            "name": "apicast.policy.fapi"
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
       ngx.header['x-fapi-interaction-id'] = "blah"
       ngx.exit(200)
     }
  }
--- request
GET /?user_key=value
--- response_headers
x-fapi-interaction-id: blah
--- error_code: 200
--- no_error_log
[error]



=== TEST 4: inject uuid to the response header
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
            "name": "apicast.policy.fapi"
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
      ngx.exit(200)
    }
  }
--- request
GET /?user_key=value
--- response_headers_like
x-fapi-interaction-id: [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$
--- error_code: 200
--- no_error_log
[error]



=== TEST 5: Validate x-fapi-customer-ip-address header
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
            "name": "apicast.policy.fapi",
            "configuration": {
              "validate_x_fapi_customer_ip_address": true
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
      ngx.exit(200)
    }
  }
--- more_headers
x-fapi-customer-ip-address: 192.168.0.1
--- request
GET /?user_key=value
--- error_code: 200
--- no_error_log
[error]



=== TEST 6: Reject request with invalid x-fapi-customer-ip-address header
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
            "name": "apicast.policy.fapi",
            "configuration": {
              "validate_x_fapi_customer_ip_address": true
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
      ngx.exit(200)
    }
  }
--- more_headers
x-fapi-customer-ip-address: something
--- request
GET /?user_key=value
--- error_code: 403
--- response_body chomp
{"error": "invalid_request"}
--- no_error_log
[error]



=== TEST 7: With oauth2_mtls enabled and digest of TLS Client Certificate equals to cnf claim
--- env random_port eval
(
  'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
  'BACKEND_ENDPOINT_OVERRIDE' => '' # disable override by Test::APIcast::Blackbox
)
--- configuration env
{
  "oidc": [
    {
      "issuer": "https://example.com/auth/realms/apicast",
      "config": { "id_token_signing_alg_values_supported": [ "RS256" ] },
      "keys": { "somekid": { "pem": "-----BEGIN PUBLIC KEY-----\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBALClz96cDQ965ENYMfZzG+Acu25lpx2K\nNpAALBQ+catCA59us7+uLY5rjQR6SOgZpCz5PJiKNAdRPDJMXSmXqM0CAwEAAQ==\n-----END PUBLIC KEY-----", "alg": "RS256" } }
    }
  ],
  "services": [
    {
      "id": 42,
      "backend_version": "oauth",
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "authentication_method": "oidc",
        "oidc_issuer_endpoint": "https://example.com/auth/realms/apicast",
        "api_backend": "http://test_backend:$TEST_NGINX_RANDOM_PORT",
        "backend": {
          "endpoint": "http://test_backend:$TEST_NGINX_RANDOM_PORT/",
          "host": "localhost"
        },
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.fapi",
            "configuration": {
              "validate_oauth2_certificate_bound_access_token": true
            }
          },
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- backend random_port env
  listen $TEST_NGINX_RANDOM_PORT;
  location /transactions/oauth_authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
  location /t {
        content_by_lua_block {
          ngx.say('yay, api backend')
        }
    }
--- test eval
my $jwt = ::authorization_bearer_jwt('audience', {
    cnf => { 'x5t#S256' => "Y4_LVlkpE6qkscPbtoKm3iiKBgfwbOfbdKBEdnZ6ZPY"
}}, 'somekid');
<<EOF
    proxy_ssl_verify on;
    proxy_ssl_trusted_certificate $Test::Nginx::Util::ServRoot/html/ca.crt;
    proxy_ssl_certificate $Test::Nginx::Util::ServRoot/html/client.crt;
    proxy_ssl_certificate_key $Test::Nginx::Util::ServRoot/html/client.key;
    proxy_pass https://\$server_addr:\$apicast_port/t;
    proxy_set_header Host localhost;
    proxy_set_header Authorization "$jwt";
    log_by_lua_block { collectgarbage() }
EOF
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 8: With oauth2_mtls enabled and TLS Client Certificate is not provided
--- env random_port eval
(
  'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
  'BACKEND_ENDPOINT_OVERRIDE' => '' # disable override by Test::APIcast::Blackbox
)
--- configuration env
{
  "oidc": [
    {
      "issuer": "https://example.com/auth/realms/apicast",
      "config": { "id_token_signing_alg_values_supported": [ "RS256" ] },
      "keys": { "somekid": { "pem": "-----BEGIN PUBLIC KEY-----\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBALClz96cDQ965ENYMfZzG+Acu25lpx2K\nNpAALBQ+catCA59us7+uLY5rjQR6SOgZpCz5PJiKNAdRPDJMXSmXqM0CAwEAAQ==\n-----END PUBLIC KEY-----", "alg": "RS256" } }
    }
  ],
  "services": [
    {
      "id": 42,
      "backend_version": "oauth",
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "authentication_method": "oidc",
        "oidc_issuer_endpoint": "https://example.com/auth/realms/apicast",
        "api_backend": "http://test_backend:$TEST_NGINX_RANDOM_PORT",
        "backend": {
          "endpoint": "http://test_backend:$TEST_NGINX_RANDOM_PORT/",
          "host": "localhost"
        },
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.fapi",
            "configuration": {
              "validate_oauth2_certificate_bound_access_token": true
            }
          },
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- backend random_port env
  listen $TEST_NGINX_RANDOM_PORT;
  location /transactions/oauth_authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
  location /t {
        content_by_lua_block {
          ngx.say('yay, api backend')
        }
    }
--- test eval
my $jwt = ::authorization_bearer_jwt('audience', {
    cnf => { 'x5t#S256' => "Y4_LVlkpE6qkscPbtoKm3iiKBgfwbOfbdKBEdnZ6ZPY"
}}, 'somekid');
<<EOF
    proxy_ssl_verify on;
    proxy_ssl_trusted_certificate $Test::Nginx::Util::ServRoot/html/ca.crt;
    proxy_pass https://\$server_addr:\$apicast_port/t;
    proxy_set_header Host localhost;
    proxy_set_header Authorization "$jwt";
    log_by_lua_block { collectgarbage() }
EOF
--- error_code: 401
--- response_body chomp
{"error": "invalid_token"}
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 9: With oauth2_mtls enabled and missing cnf claim
--- env random_port eval
(
  'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
  'BACKEND_ENDPOINT_OVERRIDE' => '' # disable override by Test::APIcast::Blackbox
)
--- configuration env
{
  "oidc": [
    {
      "issuer": "https://example.com/auth/realms/apicast",
      "config": { "id_token_signing_alg_values_supported": [ "RS256" ] },
      "keys": { "somekid": { "pem": "-----BEGIN PUBLIC KEY-----\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBALClz96cDQ965ENYMfZzG+Acu25lpx2K\nNpAALBQ+catCA59us7+uLY5rjQR6SOgZpCz5PJiKNAdRPDJMXSmXqM0CAwEAAQ==\n-----END PUBLIC KEY-----", "alg": "RS256" } }
    }
  ],
  "services": [
    {
      "id": 42,
      "backend_version": "oauth",
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "authentication_method": "oidc",
        "oidc_issuer_endpoint": "https://example.com/auth/realms/apicast",
        "api_backend": "http://test_backend:$TEST_NGINX_RANDOM_PORT",
        "backend": {
          "endpoint": "http://test_backend:$TEST_NGINX_RANDOM_PORT/",
          "host": "localhost"
        },
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.fapi",
            "configuration": {
              "validate_oauth2_certificate_bound_access_token": true
            }
          },
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- backend random_port env
  listen $TEST_NGINX_RANDOM_PORT;
  location /transactions/oauth_authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
  location /t {
        content_by_lua_block {
          ngx.say('yay, api backend')
        }
    }
--- test eval
my $jwt = ::authorization_bearer_jwt('audience', {
    foo => "1",
}, 'somekid');
<<EOF
    proxy_ssl_verify on;
    proxy_ssl_trusted_certificate $Test::Nginx::Util::ServRoot/html/ca.crt;
    proxy_ssl_certificate $Test::Nginx::Util::ServRoot/html/client.crt;
    proxy_ssl_certificate_key $Test::Nginx::Util::ServRoot/html/client.key;
    proxy_pass https://\$server_addr:\$apicast_port/t;
    proxy_set_header Host localhost;
    proxy_set_header Authorization "$jwt";
    log_by_lua_block { collectgarbage() }
EOF
--- error_code: 401
--- response_body chomp
{"error": "invalid_token"}
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 10: Digest of TLS Client Certificate does not equal cnf claim
--- env random_port eval
(
  'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
  'BACKEND_ENDPOINT_OVERRIDE' => '' # disable override by Test::APIcast::Blackbox
)
--- configuration env
{
  "oidc": [
    {
      "issuer": "https://example.com/auth/realms/apicast",
      "config": { "id_token_signing_alg_values_supported": [ "RS256" ] },
      "keys": { "somekid": { "pem": "-----BEGIN PUBLIC KEY-----\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBALClz96cDQ965ENYMfZzG+Acu25lpx2K\nNpAALBQ+catCA59us7+uLY5rjQR6SOgZpCz5PJiKNAdRPDJMXSmXqM0CAwEAAQ==\n-----END PUBLIC KEY-----", "alg": "RS256" } }
    }
  ],
  "services": [
    {
      "id": 42,
      "backend_version": "oauth",
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "authentication_method": "oidc",
        "oidc_issuer_endpoint": "https://example.com/auth/realms/apicast",
        "api_backend": "http://test_backend:$TEST_NGINX_RANDOM_PORT",
        "backend": {
          "endpoint": "http://test_backend:$TEST_NGINX_RANDOM_PORT/",
          "host": "localhost"
        },
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.fapi",
            "configuration": {
              "validate_oauth2_certificate_bound_access_token": true
            }
          },
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- backend random_port env
  listen $TEST_NGINX_RANDOM_PORT;
  location /transactions/oauth_authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
  location /t {
        content_by_lua_block {
          ngx.say('yay, api backend')
        }
    }
--- test eval
my $jwt = ::authorization_bearer_jwt('audience', {
    cnf => { 'x5t#S256' => "invalid"
}}, 'somekid');
<<EOF
    proxy_ssl_verify on;
    proxy_ssl_trusted_certificate $Test::Nginx::Util::ServRoot/html/ca.crt;
    proxy_ssl_certificate $Test::Nginx::Util::ServRoot/html/client.crt;
    proxy_ssl_certificate_key $Test::Nginx::Util::ServRoot/html/client.key;
    proxy_pass https://\$server_addr:\$apicast_port/t;
    proxy_set_header Host localhost;
    proxy_set_header Authorization "$jwt";
    log_by_lua_block { collectgarbage() }
EOF
--- error_code: 401
--- response_body chomp
{"error": "invalid_token"}
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval
