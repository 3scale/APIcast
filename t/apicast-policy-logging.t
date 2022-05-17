use lib 't';
use Test::APIcast::Blackbox 'no_plan';

our $private_key = `cat t/fixtures/rsa.pem`;
our $public_key = `cat t/fixtures/rsa.pub`;

# Test::Nginx does not allow to grep access logs, so we redirect them to
# stderr to be able to use "grep_error_log" by setting APICAST_ACCESS_LOG_FILE
$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";
$ENV{APICAST_HTTPS_RANDOM_PORT} = Test::APIcast::get_random_port();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: Enables access logs when configured to do so
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "enable_access_logs": true
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
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /
--- error_code: 200
--- grep_error_log eval
[qr/"GET \W+ HTTP\/1.1" 200/]
--- grep_error_log_out
"GET / HTTP/1.1" 200
--- no_error_log
[error]

=== TEST 2: Disables access logs when configured to do so
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "enable_access_logs": false
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
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /
--- error_code: 200
--- grep_error_log eval
qr/"GET \W+ HTTP\/1.1" 200/
--- grep_error_log_out
--- no_error_log
[error]

=== TEST 3: Enables access logs by default when the policy is included
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": { }
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
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /
--- error_code: 200
--- grep_error_log eval
[qr/"GET \W+ HTTP\/1.1" 200/]
--- grep_error_log_out
"GET / HTTP/1.1" 200
--- no_error_log
[error]

=== TEST 4: service uses a custom access log format
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
                "custom_logging": "Status::{{ status }}"
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
--- request
GET /
--- error_code: 200
--- error_log eval
[ qr/^Status\:\:200/ ]
--- no_error_log eval
[qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/]

=== TEST 5: service uses a custom access log format with a valid condition
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
                "custom_logging": "Status::{{ status }}",
                "condition": {
                "operations": [
                  {"op": "==", "match": "{{status}}", "match_type": "liquid", "value": "200", "value_type": "plain"}
                ],
                "combine_op": "and"
              }
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
--- request
GET /
--- error_code: 200
--- error_log eval
[ qr/^Status\:\:200/ ]
--- no_error_log eval
[qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/]

=== TEST 6: service uses a custom access log format with a not match condition
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
                "custom_logging": "Status::{{ status }}",
                "condition": {
                "operations": [
                  {"op": "==", "match": "{{status}}", "match_type": "liquid", "value": "201", "value_type": "plain"}
                ],
                "combine_op": "and"
              }
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
--- request
GET /
--- error_code: 200
--- no_error_log eval
[qr/^Status::200$/, qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/]


=== TEST 7: service metadata is retrieved in the access_log
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "custom_logging": "Status::{{ status }} {{service.id}}"
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
--- request
GET /
--- error_code: 200
--- error_log eval
[ qr/^Status\:\:200 42/ ]
--- no_error_log eval
[qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/]


=== TEST 8: other services do not inherit access log configuration
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "hosts": [
          "one"
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "custom_logging": "Status::{{ status }} {{service.id}}"
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
    },
    {
      "id": 21,
      "proxy": {
        "hosts": [
          "two"
        ],
        "policy_chain": [
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
--- pipelined_requests eval
["GET /","GET /second_service"]
--- more_headers eval
["Host: one", "Host: two"]
--- error_code eval
[200, 200]
--- error_log eval
[ qr/^Status\:\:200 42/, qr/GET \/second_service HTTP\/1.1/]
--- no_error_log eval
[qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/]


=== TEST 9: json log with no valid data return empty object
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "custom_logging": "Status::{{ status }} {{service.id}}",
              "enable_json_logs": true
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
--- request
GET /
--- error_code: 200
--- error_log eval
[qr/^\{\}/]
--- no_error_log eval
[qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/, qr/^Status\:\:200/]

=== TEST 10: json log with valid data return a valid json
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "custom_logging": "Status::{{ status }} {{service.id}}",
              "enable_json_logs": true,
              "json_object_config": [
				{
				  "key": "host",
				  "value": "{{host}}",
				  "value_type": "liquid"
				}
              ]
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
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /
--- error_code: 200
--- error_log eval
[qr/^\{\"host\"\:\"echo\"\}/]
--- no_error_log eval
[qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/]

=== TEST 11: Original request information can be retrieved correctly
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "custom_logging": "Status::{{ status }} {{service.id}} {{host}} {{original_request.host}}",
              "enable_json_logs": false
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
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /
--- error_code: 200
--- error_log eval
[qr/^Status\:\:200 42 echo localhost/]
--- no_error_log eval
[qr/\[error/, qr/GET \/ HTTP\/1.1\" 200/]


=== TEST 12: Verify JWT information on logs
--- configuration env eval
use JSON qw(to_json);

to_json({
  services => [{
    id => 42,
    backend_version => 'oauth',
    backend_authentication_type => 'provider_key',
    backend_authentication_value => 'fookey',
    proxy => {
        authentication_method => 'oidc',
        oidc_issuer_endpoint => 'https://example.com/auth/realms/apicast',
        api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
        proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
        ],
        policy_chain => [
            {
                name => "apicast.policy.logging",
                configuration => {
                    custom_logging => "AUD::{{jwt.aud}}",
                    enable_json_logs => JSON::false
                }
            },
            { name => "apicast.policy.apicast" }
        ]
    }
  }],
  oidc => [{
    issuer => 'https://example.com/auth/realms/apicast',
    config => { id_token_signing_alg_values_supported => [ 'RS256' ] },
    keys => { somekid => { pem => $::public_key, alg => 'RS256' } },
  }]
});
--- upstream
  location /test {
    echo "yes";
  }
--- backend
  location = /transactions/oauth_authrep.xml {
    content_by_lua_block {
      local expected = "provider_key=fookey&service_id=42&usage%5Bhits%5D=1&app_id=appid"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- request: GET /test
--- error_code: 200
--- more_headers eval
use Crypt::JWT qw(encode_jwt);
my $jwt = encode_jwt(payload => {
  aud => 'something',
  azp => 'appid',
  sub => 'someone',
  iss => 'https://example.com/auth/realms/apicast',
  exp => time + 3600 }, key => \$::private_key, alg => 'RS256', extra_headers => { kid => 'somekid' });
"Authorization: Bearer $jwt"
--- error_log eval
[qr/^AUD::something/]
--- no_error_log
[error]

=== TEST 13: Verify credentials on logs
Some users want to log some credentials on the log for debugging purposes.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "hosts": [
          "localhost"
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "custom_logging": "Status::{{ status }} USER_KEY::{{credentials.user_key }} {{service.id}}",
              "enable_json_logs": false
            }
          },
          {
            "name": "apicast",
            "version": "builtin",
            "configuration": {}
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
--- upstream env
location / {
  access_by_lua_block {
      ngx.say("OK")
  }
}
--- request
GET /?user_key=123
--- response_body env
OK
--- error_code: 200
--- error_log eval
[qr/^Status\:\:200 USER_KEY\:\:123 42/]
--- no_error_log
[error]

=== TEST 14: APICAST_ACCESS_LOG_BUFFER env parameter
When buffer is enabled, log will be bumped in chunks
--- env eval
('APICAST_ACCESS_LOG_BUFFER' => '1k')
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "hosts": [
          "localhost"
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "custom_logging": "Status::{{ status }} USER_KEY::{{credentials.user_key }} {{service.id}}",
              "enable_json_logs": false
            }
          },
          {
            "name": "apicast",
            "version": "builtin",
            "configuration": {}
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
--- upstream env
location / {
  access_by_lua_block {
      ngx.say("OK")
  }
}
--- request
GET /?user_key=123
--- response_body env
OK
--- error_code: 200
--- no_error_log eval
[qr/^Status\:\:200 USER_KEY\:\:123 42/]

=== TEST 15: original_request must contain the right information 
for requests after the first when the same TCP connection is reused
--- env eval
(
    'APICAST_HTTPS_PORT' => $ENV{APICAST_HTTPS_RANDOM_PORT},
    'HTTP_KEEPALIVE_TIMEOUT' => '5'
)
--- backend
location /transactions/authrep.xml {
  content_by_lua_block {
    ngx.exit(200)
  }
}
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version": 1,
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api-backend/",
        "hosts": ["127.0.0.1"],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.logging",
            "configuration": {
              "custom_logging": "Status::{{ status }} {{original_request.path}}",
              "enable_json_logs": false
            }
          }
        ],
        "proxy_rules": [
          {
            "pattern": "/one",
            "http_method": "GET",
            "metric_system_name": "hits",
            "delta": 1
          },
          {
            "pattern": "/two",
            "http_method": "GET",
            "metric_system_name": "hits",
            "delta": 1
          }
        ]
      }
    }
  ]
}
--- upstream
location ~ /api-backend(/.+) {
  echo 'yay, api backend: $1';
}
--- test
content_by_lua_block {
  local http = require "resty.http"
  local resty_env = require 'resty.env'

  local https_port = resty_env.get('APICAST_HTTPS_PORT')
  local httpc = http.new()
  httpc:connect("127.0.0.1", https_port)
  httpc:ssl_handshake(nil, "127.0.0.1", false)

  local responses, err = httpc:request_pipeline({
    {
      method = "GET",
      path = "/one",
      version = 1.1,
      ssl_verify = false,
      query = "?user_key=foo"
    },
    {
      method = "GET",
      path = "/two",
      version = 1.1,
      ssl_verify = false,
      query = "?user_key=foo"
    }
  })

  local res1 = responses[1]
  res1.body = responses[1]:read_body()
  local res2 = responses[2]
  res2.body = responses[2]:read_body()

  assert(responses[1], "Request failed"..(err or ""))
  assert(responses[2], "Request failed"..(err or ""))
  httpc:close()
}
--- no_error_log
[error]
--- error_log eval
[qr/^Status\:\:200 \/one/, qr/^Status\:\:200 \/two/]
