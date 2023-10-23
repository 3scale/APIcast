use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: round robin does not leak memory
Balancing different hosts does not leak memory.
--- configuration
  {
      "services": [
      {
          "proxy": {
            "policy_chain": [
            { "name": "apicast.policy.upstream",
              "configuration":
              {
                "rules": [ { "regex": "/", "http_method": "GET",
                             "url": "http://test:$TEST_NGINX_SERVER_PORT" } ]
              }
            }
            ]
        }
      }
    ]
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
[ "GET /t", "GET /t" ]
--- response_body eval
[ "1", "1" ]
