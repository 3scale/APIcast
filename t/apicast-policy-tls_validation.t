use lib 't';
use Test::APIcast::Blackbox 'no_plan';

env_to_apicast(
    'APICAST_HTTPS_PORT' => "$Test::Nginx::Util::ServerPortForClient",
    'APICAST_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/server.crt",
    'APICAST_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/server.key",
    'APICAST_HTTPS_SESSION_REUSE' => 'on',
);

run_tests();

__DATA__

=== TEST 1: TLS Client Certificate is whitelisted and valid
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/client.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 2: TLS Client Certificate CA is whitelisted
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 3: TLS Client Certificate is not whitelisted
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [ ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
TLS certificate validation failed
--- error_code: 400
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 4: TLS Client Certificate is not provided
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [ ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
No required TLS certificate was sent
--- error_code: 400
--- no_error_log
[error]
[alert]
--- user_files fixture=CA/files.pl eval



=== TEST 5: TLS Client Certificate contains whole certificate chain
--- env eval
("APICAST_HTTPS_VERIFY_DEPTH" => 2)
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client-bundle.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 6: TLS Client Certificate request client certificate when "APICAST_HTTPS_VERIFY_CLIENT: off"
and the policy is in the chain
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
    }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 7: TLS Client Certificate request client certificate with path routing enabled
--- env eval
('APICAST_PATH_ROUTING' => '1')
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    id => 2,
    backend_version => 1,
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
      }
  }, {
    id => 3,
    backend_version => 1,
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.echo', configuration => { status => 404 }}
        ]
      }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
GET /t HTTP/1.0
--- error_code: 200
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval



=== TEST 8: TLS Client Certificate request client certificate with "APICAST_HTTPS_VERIFY_CLIENT: off"
and path routing enabled
When path routing is enabled, APIcast will not able to select the correct service and build the
corresponding policy chain during the TLS handshake. It will then fallback to the setting defined by
`ssl_client_verify` and with `APICAST_HTTPS_VERIFY_CLIENT` is set to `off`, no client certificate will
be requested.
--- env eval
(
  'APICAST_PATH_ROUTING' => '1',
  'APICAST_HTTPS_VERIFY_CLIENT' => 'off'
)
--- configuration eval
use JSON qw(to_json);
use File::Slurp qw(read_file);

to_json({
  services => [{
    id => 2,
    backend_version => 1,
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.tls_validation',
            configuration => {
              whitelist => [
                { pem_certificate => CORE::join('', read_file('t/fixtures/CA/intermediate-ca.crt')) }
              ]
            }
          },
          { name => 'apicast.policy.echo' },
        ]
      }
  }, {
    id => 3,
    backend_version => 1,
    proxy => {
        hosts => ['test'],
        policy_chain => [
          { name => 'apicast.policy.echo', configuration => { status => 404 }}
        ]
      }
  }]
});
--- test env
proxy_ssl_verify on;
proxy_ssl_trusted_certificate $TEST_NGINX_SERVER_ROOT/html/ca.crt;
proxy_ssl_certificate $TEST_NGINX_SERVER_ROOT/html/client.crt;
proxy_ssl_certificate_key $TEST_NGINX_SERVER_ROOT/html/client.key;
proxy_pass https://$server_addr:$apicast_port/t;
proxy_set_header Host test;
log_by_lua_block { collectgarbage() }
--- response_body
No required TLS certificate was sent
--- error_code: 400
--- no_error_log
[error]
--- user_files fixture=CA/files.pl eval
