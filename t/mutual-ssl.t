use lib 't';
use Test::APIcast::Blackbox 'no_plan';

env_to_apicast(
    'APICAST_PROXY_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/client.crt",
    'APICAST_PROXY_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/client.key",
    'APICAST_PROXY_HTTPS_SESSION_REUSE' => 'on'
);

run_tests();

__DATA__

=== TEST 1: Mutual SSL with password file
--- env eval
(
  'APICAST_PROXY_HTTPS_PASSWORD_FILE' => "$Test::Nginx::Util::ServRoot/html/passwords.file"
)
--- configuration random_port env
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "https://test:$TEST_NGINX_RANDOM_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
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
  listen $TEST_NGINX_RANDOM_PORT ssl;

  ssl_certificate $TEST_NGINX_SERVER_ROOT/html/server.crt;
  ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/server.key;

  ssl_client_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
  ssl_verify_client on;

  location / {
     echo 'ssl_client_s_dn: $ssl_client_s_dn';
     echo 'ssl_client_i_dn: $ssl_client_i_dn';
  }
--- request
GET /?user_key=uk
--- response_body
ssl_client_s_dn: CN=localhost,OU=APIcast,O=3scale
ssl_client_i_dn: CN=localhost,OU=APIcast,O=3scale
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=mutual_ssl.pl eval



=== TEST 2: Do not request client certificate when APICAST_HTTPS_VERIFY_CLIENT=off
--- env eval
(
  'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
  'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
  'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
  'APICAST_HTTPS_VERIFY_CLIENT' => "off",
  'BACKEND_ENDPOINT_OVERRIDE' => '' # disable override by Test::APIcast::Blackbox
)
--- backend random_port env
  listen $TEST_NGINX_RANDOM_PORT;
  location /transactions/oauth_authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }

  location /t {
    content_by_lua_block {
      print('client certificate subject: ', ngx.var.ssl_client_s_dn)
      print('client certificate: ', ngx.var.ssl_client_raw_cert)
      ngx.say(ngx.var.ssl_client_verify)
    }
  }
--- configuration random_port env
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "hosts": ["test"],
        "api_backend": "http://test_backend:$TEST_NGINX_RANDOM_PORT/",
        "backend": {
          "endpoint": "http://test_backend:$TEST_NGINX_RANDOM_PORT/",
          "host": "localhost"
        },
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          { "name": "apicast.policy.apicast" }
        ]
      }
    }
  ]
}
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t?user_key=;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
nil
--- error_log
client certificate subject: nil
client certificate: nil
--- no_error_log
[error]
[alert]
[crit]
--- user_files fixture=CA/files.pl eval
