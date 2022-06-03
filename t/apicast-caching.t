use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";

repeat_each(1); # Can't be two as the second call would hit the cache
run_tests();

__DATA__

=== TEST 1: call to backend is cached
First call is done synchronously and the second out of band.
--- configuration
{
    "services": [{
        "id": 42,
        "backend_version": 1,
        "backend_authentication_type": "service_token",
        "backend_authentication_value": "token-value",
        "proxy": {
          "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
          "proxy_rules": [
            { "pattern":  "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 2 }
          ]
        }
    }]
}
--- backend
    location /transactions/authrep.xml {
      content_by_lua_block {
        ngx.exit(200)
      }
    }
--- upstream
location /t {
    echo 'yay, api backend';
}
--- pipelined_requests eval
["GET /t?user_key=value","GET /t?user_key=value"]
--- response_body eval
["yay, api backend\n", "yay, api backend\n"]
--- error_code eval
[200, 200]
--- grep_error_log_out
apicast cache miss key: 42:value:usage%5Bhits%5D=2
apicast cache write key: 42:value:usage%5Bhits%5D=2
apicast cache hit key: 42:value:usage%5Bhits%5D=2

=== TEST 2: multi service configuration
Two services can exist together and are split by their hostname.
--- configuration
{
    "services": [
    {
        "id": 1,
        "backend_version": 1,
        "backend_authentication_type": "service_token",
        "backend_authentication_value": "service-one",
        "proxy": {
          "hosts": [ "one" ],
          "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/one",
          "proxy_rules": [
            { "pattern":  "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 1 }
          ]
        }
    },
    {
        "id": 2,
        "backend_version": 2,
        "backend_authentication_type": "service_token",
        "backend_authentication_value": "service-two",
        "proxy": {
          "hosts": [ "two" ],
          "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/two",
          "proxy_rules": [
            { "pattern":  "/", "http_method" : "GET", "metric_system_name" : "hits", "delta" : 2 }
          ]
        }
    }
    ]
}
--- backend
    location /transactions/authrep.xml {
      content_by_lua_block {
          if ngx.var.arg_service_id == '1' then
            if ngx.var.arg_service_token == 'service-one' then
             return ngx.exit(200)
           end
         elseif ngx.var.arg_service_id == '2' then
           if ngx.var.arg_service_token == 'service-two' then
             return ngx.exit(200)
           end
         end

         ngx.exit(403)
      }
    }
--- upstream
location /one/one-resource {
    echo 'yay, api backend: one';
}

location /two/two-resource {
    echo 'yay, api backend: two';
}
--- pipelined_requests eval
["GET /one-resource?user_key=one-key","GET /two-resource?app_id=two-id&app_key=two-key"]
--- more_headers eval
["Host: one","Host: two"]
--- response_body eval
["yay, api backend: one\n", "yay, api backend: two\n"]
--- error_code eval
[200, 200]
--- no_error_log eval
[qr/\[error\]/, qr/\[error\]/]
--- grep_error_log_out
apicast cache miss key: 1:one-key:usage%5Bhits%5D=1
apicast cache write key: 1:one-key:usage%5Bhits%5D=1
apicast cache miss key: 2:two-id:two-key:usage%5Bhits%5D=2
apicast cache write key: 2:two-id:two-key:usage%5Bhits%5D=2
