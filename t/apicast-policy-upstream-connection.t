use lib 't';
use Test::APIcast::Blackbox 'no_plan';

require("http_proxy.pl");

run_tests();

__DATA__

=== TEST 1: Set timeouts
In this test we set some timeouts to 1s. To force a read timeout, the upstream
returns part of the response, then waits 3s (more than the timeout defined),
and after that, it returns the rest of the response.
This test uses the "ignore_response" section, because we know that the response
is not going to be complete and that makes the Test::Nginx framework raise an
error. With "ignore_response" that error is ignored.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "api_backend": "http://example.com:80/",
        "policy_chain": [
          {
            "name": "apicast.policy.upstream_connection",
            "configuration": {
              "connect_timeout": 1,
              "send_timeout": 1,
              "read_timeout": 1
            }
          },
          {
            "name": "apicast.policy.upstream",
            "configuration": {
              "rules": [
                {
                  "regex": "/",
                  "url": "http://test:$TEST_NGINX_SERVER_PORT"
                }
              ]
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
       ngx.say("first part")
       ngx.flush(true)
       ngx.sleep(3)
       ngx.say("yay, second part")
     }
  }
--- request
GET /
--- ignore_response
--- error_log
upstream timed out

=== TEST 2: Set timeouts using HTTPS proxy for backend
In this test we set some timeouts to 1s. To force a read timeout, the upstream
returns part of the response, then waits 3s (more than the timeout defined),
and after that, it returns the rest of the response. Backend is configured with https_proxy
This test uses the "ignore_response" section, because we know that the response
is not going to be complete and that makes the Test::Nginx framework raise an
error. With "ignore_response" that error is ignored.
--- configuration random_port env
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/test", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.upstream_connection",
            "configuration": {
              "connect_timeout": 1,
              "send_timeout": 1,
              "read_timeout": 1
            }
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "https_proxy": "$TEST_NGINX_HTTPS_PROXY"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream env
server_name test-upstream.lvh.me;
listen $TEST_NGINX_RANDOM_PORT ssl;

ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

location /test {
    content_by_lua_block {
      ngx.say("first part")
      ngx.flush(true)
      ngx.sleep(3)
      ngx.say("yay, second part")
    }

    access_by_lua_block {
      assert = require('luassert')
      assert.equal('https', ngx.var.scheme)
      assert.equal('$TEST_NGINX_RANDOM_PORT', ngx.var.server_port)
      assert.equal('test-upstream.lvh.me', ngx.var.ssl_server_name)

      local host = ngx.req.get_headers()["Host"]
      local result = string.match(host, "^test%-upstream%.lvh%.me:")
      assert.equals(result, "test-upstream.lvh.me:")
    }
}
--- request
GET /test?user_key=test3
--- ignore_response
--- more_headers
User-Agent: Test::APIcast::Blackbox
ETag: foobar
--- error_log env
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
using proxy: $TEST_NGINX_HTTPS_PROXY
failed to read response body: timeout
--- user_files fixture=tls.pl eval

=== TEST 3: Set timeouts using HTTPS proxy for backend using HTTPS_PROXY env var
In this test we set some timeouts to 1s. To force a read timeout, the upstream
returns part of the response, then waits 3s (more than the timeout defined),
and after that, it returns the rest of the response. Backend is configured with https_proxy
This test uses the "ignore_response" section, because we know that the response
is not going to be complete and that makes the Test::Nginx framework raise an
error. With "ignore_response" that error is ignored.
--- env eval
(
  "https_proxy" => $ENV{TEST_NGINX_HTTPS_PROXY},
)
--- configuration random_port env
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/test", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.upstream_connection",
            "configuration": {
              "connect_timeout": 1,
              "send_timeout": 1,
              "read_timeout": 1
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream env
server_name test-upstream.lvh.me;
listen $TEST_NGINX_RANDOM_PORT ssl;
ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

location /test {
    content_by_lua_block {
      ngx.say("first part")
      ngx.flush(true)
      ngx.sleep(3)
      ngx.say("yay, second part")
    }

    access_by_lua_block {
      assert = require('luassert')
      assert.equal('https', ngx.var.scheme)
      assert.equal('$TEST_NGINX_RANDOM_PORT', ngx.var.server_port)
      assert.equal('test-upstream.lvh.me', ngx.var.ssl_server_name)

      local host = ngx.req.get_headers()["Host"]
      local result = string.match(host, "^test%-upstream%.lvh%.me:")
      assert.equals(result, "test-upstream.lvh.me:")
    }
}

--- request
GET /test?user_key=test3
--- more_headers
User-Agent: Test::APIcast::Blackbox
ETag: foobar
--- error_log env
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
using proxy: $TEST_NGINX_HTTPS_PROXY
failed to read response body: timeout
--- user_files fixture=tls.pl eval

=== TEST 4: Set timeouts using HTTPS Camel proxy for backend
In this test we set some timeouts to 1s. To force a read timeout, the upstream
returns part of the response, then waits 3s (more than the timeout defined),
and after that, it returns the rest of the response. Backend is configured with https_proxy
This test uses the "ignore_response" section, because we know that the response
is not going to be complete and that makes the Test::Nginx framework raise an
error. With "ignore_response" that error is ignored.
--- configuration random_port env
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/test", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.upstream_connection",
            "configuration": {
              "connect_timeout": 1,
              "send_timeout": 1,
              "read_timeout": 1
            }
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "https_proxy": "$TEST_NGINX_HTTPS_PROXY"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream env
server_name test-upstream.lvh.me;
listen $TEST_NGINX_RANDOM_PORT ssl;

ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

location /test {
    content_by_lua_block {
      ngx.say("first part")
      ngx.flush(true)
      ngx.sleep(3)
      ngx.say("yay, second part")
    }

    access_by_lua_block {
      assert = require('luassert')
      assert.equal('https', ngx.var.scheme)
      assert.equal('$TEST_NGINX_RANDOM_PORT', ngx.var.server_port)
      assert.equal('test-upstream.lvh.me', ngx.var.ssl_server_name)

      local host = ngx.req.get_headers()["Host"]
      local result = string.match(host, "^test%-upstream%.lvh%.me:")
      assert.equals(result, "test-upstream.lvh.me:")
    }
}
--- request
GET /test?user_key=test3
--- ignore_response
--- more_headers
User-Agent: Test::APIcast::Blackbox
ETag: foobar
--- error_log env
using proxy: $TEST_NGINX_HTTPS_PROXY
err: timeout
--- user_files fixture=tls.pl eval



=== TEST 5: upstream_connection policy inside conditional policy
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/test",
                    "right_type": "plain"
                  }
                ]
              },
              "policy_chain": [
                {
                  "name": "apicast.policy.upstream_connection",
                  "configuration": {
                    "connect_timeout": 1,
                    "send_timeout": 1,
                    "read_timeout": 1
                  }
                }
              ]
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream
  server_name test-upstream.lvh.me;
  location /test {
    content_by_lua_block {
      ngx.say("first part")
      ngx.flush(true)
      ngx.sleep(3)
      ngx.say("yay, second part")
    }
  }
--- request
GET /test?user_key=value
--- ignore_response
--- error_log
upstream timed out



=== TEST 6: upstream_connection policy inside conditional policy with false condition
In this test the upstream returns part of the response, then waits 3s and after
that, it returns the rest of the response. We set timeouts to 1s inside the conditional
policy but due to false condition, the default timeout of 60s should take effect and we
should receive the whole response back
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": {
                "operations": [
                  {
                    "left": "{{ uri }}",
                    "left_type": "liquid",
                    "op": "==",
                    "right": "/invalid",
                    "right_type": "plain"
                  }
                ]
              },
              "policy_chain": [
                {
                  "name": "apicast.policy.upstream_connection",
                  "configuration": {
                    "connect_timeout": 0.1,
                    "send_timeout": 0.1,
                    "read_timeout": 0.1
                  }
                }
              ]
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream
  server_name test-upstream.lvh.me;
  location /test {
    content_by_lua_block {
      ngx.say("first part")
      ngx.flush(true)
      ngx.sleep(0.2)
      ngx.say("yay, second part")
    }
  }
--- request
GET /test?user_key=value
--- response_body eval
"first part\x{0a}yay, second part\x{0a}"
--- error_code: 200
--- no_error_log
[error]
