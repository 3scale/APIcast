use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{TEST_NGINX_HTTP_CONFIG} = "$Test::APIcast::path/http.d/*.conf";
$ENV{RESOLVER} = '127.0.1.1:5353';

env_to_nginx(
    'RESOLVER'
);
master_on();
run_tests();

__DATA__

=== TEST 1: round robin does not leak memory
Balancing different hosts does not leak memory.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('resty.balancer.round_robin').cache_size = 1
  }
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "proxy" : {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "bar", "delta" : 1 }
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
location = / {
  content_by_lua_block {
    local round_robin = require('resty.balancer.round_robin')
    local balancer = round_robin.new()

    local peers = { hash = ngx.var.request_id, cur = 1,  1, 2 }
    local peer = round_robin.call(peers)

    ngx.print(peer)
  }
}
--- pipelined_requests eval
[ "GET /?user_key=value", "GET /?user_key=value" ]
--- response_body eval
[ "1", "1" ]
