use lib 't';
use Test::APIcast::Blackbox 'no_plan';

require("http_proxy.pl");

sub large_body {
  my $res = "";
  for (my $i=0; $i <= 1024; $i++) {
    $res = $res . "1111111 1111111 1111111 1111111\n";
  }
  return $res;
}


$ENV{'LARGE_BODY'} = large_body();
require("policies.pl");

repeat_each(3);

run_tests();

__DATA__

=== TEST 1: API backend connection uses proxy
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
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "http_proxy": "$TEST_NGINX_HTTP_PROXY"
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
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      local host = ngx.req.get_headers()["Host"]
      local result = string.match(host, "^test%-upstream%.lvh%.me:")
      local assert = require('luassert')
      assert.equals(result, "test-upstream.lvh.me:")
      ngx.say("yay, api backend")
    }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY

=== TEST 2: API backend using all_proxy
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
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "all_proxy": "$TEST_NGINX_HTTP_PROXY"
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
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      local host = ngx.req.get_headers()["Host"]
      local result = string.match(host, "^test%-upstream%.lvh%.me:")
      local assert = require('luassert')
      assert.equals(result, "test-upstream.lvh.me:")
      ngx.say("yay, api backend")
    }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY


=== TEST 3: using HTTPS proxy for backend
--- configuration random_port env
{
  "services": [
    {
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "secret_token": "token",
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/test", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "https_proxy": "$TEST_NGINX_HTTPS_PROXY"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream env
server_name test-upstream.lvh.me;
listen $TEST_NGINX_RANDOM_PORT ssl;

ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

location /test {
    echo_foreach_split '\r\n' $echo_client_request_headers;
    echo $echo_it;
    echo_end;

    access_by_lua_block {
      assert = require('luassert')
      assert.equal('https', ngx.var.scheme)
      assert.equal('$TEST_NGINX_RANDOM_PORT', ngx.var.server_port)
      assert.equal('test-upstream.lvh.me', ngx.var.ssl_server_name)
      assert.is_nil(ngx.var.http_x_3scale_debug)

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
X-3scale-debug: token-value
--- expected_response_body_like_multiple eval
[[
    qr{GET \/test\?user_key=test3 HTTP\/1\.1},
    qr{ETag\: foobar},
    qr{Connection\: close},
    qr{User\-Agent\: Test\:\:APIcast\:\:Blackbox},
    qr{Host\: test-upstream.lvh.me\:\d+},
    qr{X\-Real\-IP\: 127.0.0.1},
    qr{X\-3scale\-proxy\-secret\-token\: token},
]]
--- error_code: 200
--- error_log env
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
using proxy: $TEST_NGINX_HTTPS_PROXY
--- user_files fixture=tls.pl eval

=== TEST 4: using HTTP proxy with Basic Auth
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
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "http_proxy": "http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location / {
    echo 'yay, api backend!';
  }
--- request
GET /?user_key=value
--- error_code: 200
--- error_log env
using proxy: http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT
proxy http request - got header line: Proxy-Authorization: Basic Zm9vOmJhcg==


=== TEST 5: using all_proxy with Basic Auth
--- configuration random_port env
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
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "all_proxy": "http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      local assert = require('luassert')
      local proxy_auth = ngx.req.get_headers()['Proxy-Authorization']
      assert.equals(proxy_auth, "Basic Zm9vOmJhcg==")
    }
  }
--- request
GET /?user_key=value
--- error_code: 200
--- error_log env
using proxy: http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT


=== TEST 6: using HTTPS proxy with Basic Auth
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
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "https_proxy": "http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream env
server_name test-upstream.lvh.me;
listen $TEST_NGINX_RANDOM_PORT ssl;

ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

location /test {
    echo_foreach_split '\r\n' $echo_client_request_headers;
    echo $echo_it;
    echo_end;

    access_by_lua_block {
      local assert = require('luassert')
      local proxy_auth = ngx.req.get_headers()['Proxy-Authorization']
      assert.falsy(proxy_auth)
    }
}
--- request
GET /test?user_key=test3
--- error_code: 200
--- user_files fixture=tls.pl eval
--- error_log env
using proxy: http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
got header line: Proxy-Authorization: Basic Zm9vOmJhcg==



=== TEST 7: using HTTP proxy with chunked request
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
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "http_proxy": "$TEST_NGINX_HTTP_PROXY"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('12', content_length)
      assert.falsy(encoding)
    }
    echo_read_request_body;
    echo $request_body;
  }
--- more_headers
Transfer-Encoding: chunked
--- request eval
"POST /?user_key=value
7\r
hello, \r
5\r
world\r
0\r
\r
"
--- response_body
hello, world
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]



=== TEST 8: API backend using all_proxy with chunked request
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
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "all_proxy": "$TEST_NGINX_HTTP_PROXY"
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
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('12', content_length)
      assert.falsy(encoding)
    }
    echo_read_request_body;
    echo $request_body;
  }
--- more_headers
Transfer-Encoding: chunked
--- request eval
"POST /?user_key=value
7\r
hello, \r
5\r
world\r
0\r
\r
"
--- response_body
hello, world
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]



=== TEST 9: using HTTPS proxy for backend with chunked request
--- configuration random_port env
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "https_proxy": "$TEST_NGINX_HTTPS_PROXY"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream env
server_name test-upstream.lvh.me;
listen $TEST_NGINX_RANDOM_PORT ssl;

ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('12', content_length)
      assert.falsy(encoding)
    }
    echo_read_request_body;
    echo $request_body;
}
--- more_headers
Transfer-Encoding: chunked
--- request eval
"POST /?user_key=value
7\r
hello, \r
5\r
world\r
0\r
\r
"
--- response_body
hello, world
--- error_code: 200
--- error_log env
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
using proxy: $TEST_NGINX_HTTPS_PROXY
--- no_error_log
[error]
--- user_files fixture=tls.pl eval



=== TEST 10: http_proxy with request_unbuffered policy
--- configuration
{
  "services": [
    {
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered"
          },
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "http_proxy": "$TEST_NGINX_HTTP_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend
server_name test_backend.lvh.me;
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location /test {
    echo_read_request_body;
    echo_request_body;
  }
--- request eval
"POST /test?user_key= \n" . $ENV{LARGE_BODY}
--- response_body eval chomp
$ENV{LARGE_BODY}
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]
--- grep_error_log eval
qr/a client request body is buffered to a temporary file/
--- grep_error_log_out
a client request body is buffered to a temporary file



=== TEST 11: http_proxy with request_unbuffered policy + chunked request
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
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered"
          },
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "http_proxy": "$TEST_NGINX_HTTP_PROXY"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('chunked', encoding)
      assert.falsy(content_length)
    }
    echo_read_request_body;
    echo_request_body;
  }
--- more_headers
Transfer-Encoding: chunked
--- request eval
my $s = "POST /test?user_key=value
".
sprintf("%x\r\n", length $ENV{"LARGE_BODY"}).
$ENV{LARGE_BODY}
."\r
0\r
\r
";
open my $out, '>/tmp/out.txt' or die $!;
print $out $s;
close $out;
$s
--- response_body eval
$ENV{"LARGE_BODY"}
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]
--- grep_error_log eval
qr/a client request body is buffered to a temporary file/
--- grep_error_log_out
a client request body is buffered to a temporary file



=== TEST 12: all_proxy with request_unbuffered policy
--- configuration
{
  "services": [
    {
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered"
          },
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "all_proxy": "$TEST_NGINX_HTTP_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend
server_name test_backend.lvh.me;
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location /test {
    echo_read_request_body;
    echo_request_body;
  }
--- request eval
"POST /test?user_key= \n" . $ENV{LARGE_BODY}
--- response_body eval chomp
$ENV{LARGE_BODY}
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]
--- grep_error_log eval
qr/a client request body is buffered to a temporary file/
--- grep_error_log_out
a client request body is buffered to a temporary file



=== TEST 13: all_proxy with request_unbuffered policy + chunked request
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
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered"
          },
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "all_proxy": "$TEST_NGINX_HTTP_PROXY"
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
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('chunked', encoding)
      assert.falsy(content_length)
    }
    echo_read_request_body;
    echo_request_body;
  }
--- more_headers
Transfer-Encoding: chunked
--- request eval
my $s = "POST /test?user_key=value
".
sprintf("%x\r\n", length $ENV{"LARGE_BODY"}).
$ENV{LARGE_BODY}
."\r
0\r
\r
";
open my $out, '>/tmp/out.txt' or die $!;
print $out $s;
close $out;
$s
--- response_body eval
$ENV{"LARGE_BODY"}
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]
--- grep_error_log eval
qr/a client request body is buffered to a temporary file/
--- grep_error_log_out
a client request body is buffered to a temporary file



=== TEST 14: https_proxy with request_unbuffered policy
--- configuration random_port env
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered"
          },
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "https_proxy": "$TEST_NGINX_HTTPS_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend env
  server_name test-backend.lvh.me;
  listen $TEST_NGINX_RANDOM_PORT ssl;
  ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
  ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;
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
    echo_read_request_body;
    echo_request_body;
}
--- request eval
"POST /test?user_key= \n" . $ENV{LARGE_BODY}
--- response_body eval chomp
$ENV{LARGE_BODY}
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTPS_PROXY
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
--- no_error_log
[error]
--- grep_error_log eval
qr/a client request body is buffered to a temporary file/
--- grep_error_log_out
a client request body is buffered to a temporary file
--- user_files fixture=tls.pl eval



=== TEST 15: https_proxy with request_unbuffered policy
--- configuration random_port env
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "request_unbuffered"
          },
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "https_proxy": "$TEST_NGINX_HTTPS_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend env
  server_name test-backend.lvh.me;
  listen $TEST_NGINX_RANDOM_PORT ssl;
  ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
  ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;
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
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('chunked', encoding)
      assert.falsy(content_length)
    }
    echo_read_request_body;
    echo_request_body;
}
--- more_headers
Transfer-Encoding: chunked
--- request eval
"POST /test?user_key=value
".
sprintf("%x\r\n", length $ENV{"LARGE_BODY"}).
$ENV{LARGE_BODY}
."\r
0\r
\r
"
--- response_body eval
$ENV{LARGE_BODY}
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTPS_PROXY
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
--- no_error_log
[error]
--- grep_error_log eval
qr/a client request body is buffered to a temporary file/
--- grep_error_log_out
a client request body is buffered to a temporary file
--- user_files fixture=tls.pl eval



=== TEST 16: http_proxy policy inside conditional policy
We only want to check that the policy is executed so only single test
with http_proxy is enough
--- configuration
{
  "services": [
    {
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
                  "name": "apicast.policy.http_proxy",
                  "configuration": {
                      "http_proxy": "$TEST_NGINX_HTTP_PROXY"
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
server_name test_backend.lvh.me;
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location /test {
    echo_read_request_body;
    echo_request_body;
  }
--- request
GET /test?user_key=
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]



=== TEST 17: Should not be triggered when combined with conditional policy and false conditions
We know that the policy outputs "using proxy: " when request is forward to proxy server, so we
can use that to verify that it was not executed.
--- configuration
{
  "services": [
    {
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
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
                  "name": "apicast.policy.http_proxy",
                  "configuration": {
                      "all_proxy": "$TEST_NGINX_HTTP_PROXY"
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
server_name test_backend.lvh.me;
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream
server_name test-upstream.lvh.me;
  location /test {
    echo_read_request_body;
    echo_request_body;
  }
--- request
POST /test?user_key=
--- error_code: 200
--- no_error_log env
["[error]",
"using proxy: $TEST_NGINX_HTTP_PROXY "]


=== TEST 18: MTLS connection to upstream via proxy failed
--- configuration random_port env
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "https_proxy": "$TEST_NGINX_HTTPS_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend env
  server_name test-backend.lvh.me;
  listen $TEST_NGINX_RANDOM_PORT ssl;
  ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
  ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;
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
ssl_client_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
ssl_verify_client on;
location /test {
  echo 'ssl_client_s_dn: \$ssl_client_s_dn';
  echo 'ssl_client_i_dn: \$ssl_client_i_dn';
}
--- request
GET /test?user_key=value
--- error_code: 400
--- error_log env
using proxy: $TEST_NGINX_HTTPS_PROXY
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
client sent no required SSL certificate while reading client request headers
--- no_error_log
[error]
--- user_files fixture=mutual_ssl.pl eval



=== TEST 19: MTLS connection to upstream via proxy when certificates are provided
--- configuration random_port env eval
<<EOF
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.upstream_mtls",
            "configuration": {
                "certificate": "$ENV{TEST_NGINX_SERVER_ROOT}/html/client.crt",
                "certificate_type": "path",
                "certificate_key": "$ENV{TEST_NGINX_SERVER_ROOT}/html/client.key",
                "certificate_key_type": "path",
                "ca_certificates": [
                  "$Test::Nginx::Util::UPSTREAM_CA_CERT"
                ],
                "verify": true
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
EOF
--- backend env
  server_name test-backend.lvh.me;
  listen $TEST_NGINX_RANDOM_PORT ssl;
  ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
  ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;
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
ssl_client_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
ssl_verify_client on;
location /test {
  echo 'ssl_client_s_dn: $ssl_client_s_dn';
  echo 'ssl_client_i_dn: $ssl_client_i_dn';
}
--- request
GET /test?user_key=value
--- response_body
ssl_client_s_dn: CN=localhost,OU=APIcast,O=3scale
ssl_client_i_dn: CN=localhost,OU=APIcast,O=3scale
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTPS_PROXY
proxy request: CONNECT test-upstream.lvh.me:$TEST_NGINX_RANDOM_PORT HTTP/1.1
--- no_error_log
[error]
--- user_files fixture=mutual_ssl.pl eval
