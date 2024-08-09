use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);

run_tests();

__DATA__

=== TEST 1: This is just a simple demonstration of the
echo directive provided by ngx_http_echo_module.
--- configuration
{
  "services" : [
    {
      "id": 42,
      "backend_version": 1,
      "proxy" : {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "bar", "delta" : 1}
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
  echo 'yay, api backend';
}
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- error_code: 200
