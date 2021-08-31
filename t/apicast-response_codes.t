use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: report response_code when it's not cached
--- env eval
('APICAST_RESPONSE_CODES' => '1')
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
          { "pattern": "/", "http_method": "GET", "metric_system_name": "mymetric", "delta": 1 }
        ],
        "policy_chain": [
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
      local test_counter = ngx.shared.test_counter or 1
      local luassert = require('luassert')
      local tablex = require("pl.tablex")
      local inpect = require("inspect").inspect

      ngx.shared.test_counter = test_counter + 1
      if test_counter == 1 then
        local expected = {
          service_id = "42",
          service_token = "token-value",
          ["usage[mymetric]"] = "1",
          user_key = "value"
        }
        luassert.same(expected, ngx.req.get_uri_args(0))
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      end

      if test_counter == 2 then
        local expected = {
          ["log[code]"] = "200",
          service_id = "42",
          service_token = "token-value",
          ["usage[hits]"] = "1",
          user_key = "value"
        }
        local result = tablex.difference(expected, ngx.req.get_uri_args(0), true)
        if result:len() > 0 then
          ngx.log(ngx.ERR, "Second authrep is not matching when it should, expected: ",
            inspect(expected), " got: ", inspect(ngx.req.get_uri_args(0)))
        end
        ngx.exit(200)
      end

      if test_counter == 3 then
        local expected = {
          ["log[code]"] = "200",
          service_id = "42",
          service_token = "token-value",
          ["usage[mymetric]"] = "1",
          user_key = "value"
        }
        local result = tablex.difference(expected, ngx.req.get_uri_args(0), true)
        if result:len() > 0 then
          ngx.log(ngx.ERR, "Third authrep is not matching when it should, expected: ",
            inspect(expected), " got: ", inspect(ngx.req.get_uri_args(0)))
        end
        ngx.exit(200)
      end
    }
  }

--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request eval
["GET /?user_key=value", "GET /?user_key=value"]
--- error_code eval
[200, 200]
--- no_error_log eval
["\[error\]", "authrep is not matching"]
