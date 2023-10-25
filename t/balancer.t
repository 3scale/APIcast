use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: round robin does not leak memory
Balancing different hosts does not leak memory.
--- configuration
{
    "services": [
     {
        "id": 42,
        "backend_version": 1,
        "backend_authentication_type": "service_token",
        "backend_authentication_value": "token-value",
        "proxy": { 
          "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
          "proxy_rules": [ { "pattern" : "/", "http_method" : "GET",
              "metric_system_name" : "hits", "delta" : 2 } ]
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
  location = /t {
    content_by_lua_block {
      require('resty.balancer.round_robin').cache_size = 1
      local round_robin = require('resty.balancer.round_robin')
      local balancer = round_robin.new()

      local peers = { hash = ngx.var.request_id, cur = 1,  1, 2 }
      local peer = round_robin.call(peers)

      ngx.print(peer)
    }
  }
--- pipelined_requests eval
[ "GET /t?user_key=value", "GET /t?user_key=value" ]
--- response_body eval
[ "1", "1" ]
