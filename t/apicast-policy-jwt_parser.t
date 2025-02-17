use lib 't';
use Test::APIcast::Blackbox 'no_plan';

our $rsa = `cat t/fixtures/rsa.pem`;

run_tests();

__DATA__

=== TEST 1: jwt_parser accepts configuration
--- configuration
{
  "services": [
    {
      "proxy": {
        "policy_chain": [
          { "name": "apicast.policy.jwt_parser",
            "configuration": { } },
          { "name": "apicast.policy.echo" }
        ]
      }
    }
  ]
}
--- request
GET /t
--- response_body
GET /t HTTP/1.1
--- error_code: 200
--- no_error_log
[error]


=== TEST 2: Uses OIDC Discovery to load OIDC configuration and verify the JWT
--- env eval
( 'APICAST_CONFIGURATION_LOADER' => 'lazy' )
--- backend
location = /realm/.well-known/openid-configuration {
  content_by_lua_block {
    local base = "http://" .. ngx.var.host .. ':' .. ngx.var.server_port
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode {
        issuer = 'https://example.com/auth/realms/apicast',
        id_token_signing_alg_values_supported = { 'RS256' },
        jwks_uri = base .. '/jwks',
    })
  }
}

location = /jwks {
  content_by_lua_block {
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say([[
        { "keys": [
            { "kty":"RSA","kid":"somekid",
              "n":"sKXP3pwND3rkQ1gx9nMb4By7bmWnHYo2kAAsFD5xq0IDn26zv64tjmuNBHpI6BmkLPk8mIo0B1E8MkxdKZeozQ","e":"AQAB",
              "alg":"RS256" }
        ] }
    ]])
  }
}
--- configuration
{
  "services": [
    {
      "proxy": {
        "policy_chain": [
            { "name": "apicast.policy.jwt_parser",
                "configuration": {
                    "issuer_endpoint": "http://test_backend:$TEST_NGINX_SERVER_PORT/realm" } },
            { "name": "apicast.policy.echo" }
         ]
      }
    }
  ]
}
--- request
GET /echo
--- more_headers eval
use Crypt::JWT qw(encode_jwt);
my $jwt = encode_jwt(payload => {
  aud => 'the_token_audience',
  sub => 'someone',
  iss => 'https://example.com/auth/realms/apicast',
  exp => time + 3600 }, key => \$::rsa, alg => 'RS256', extra_headers => { kid => 'somekid' });
"Authorization: Bearer $jwt"
--- error_code: 200
--- response_body
GET /echo HTTP/1.1
--- no_error_log
[error]



=== TEST 3: Uses OIDC Discovery to load OIDC configuration but ignore due to
incompatible authentication method
--- env eval
( 'APICAST_CONFIGURATION_LOADER' => 'lazy' )
--- backend
location = /realm/.well-known/openid-configuration {
  content_by_lua_block {
    local base = "http://" .. ngx.var.host .. ':' .. ngx.var.server_port
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode {
        issuer = 'https://example.com/auth/realms/apicast',
        id_token_signing_alg_values_supported = { 'RS256' },
        jwks_uri = base .. '/jwks',
    })
  }
}

location = /jwks {
  content_by_lua_block {
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say([[
        { "keys": [
            { "kty":"RSA","kid":"somekid",
              "n":"sKXP3pwND3rkQ1gx9nMb4By7bmWnHYo2kAAsFD5xq0IDn26zv64tjmuNBHpI6BmkLPk8mIo0B1E8MkxdKZeozQ","e":"AQAB",
              "alg":"RS256" }
        ] }
    ]])
  }
}
--- configuration
{
  "oidc": [
    {
      "issuer": "https://example.com/auth/realms/apicast",
      "config": { "id_token_signing_alg_values_supported": [ "RS256" ] },
      "keys": { "somekid": { "pem": "-----BEGIN PUBLIC KEY-----\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBALClz96cDQ965ENYMfZzG+Acu25lpx2K\nNpAALBQ+catCA59us7+uLY5rjQR6SOgZpCz5PJiKNAdRPDJMXSmXqM0CAwEAAQ==\n-----END PUBLIC KEY-----", "alg": "RS256" } }
    }
  ],
  "services": [
    {
      "id": 42,
      "backend_version": "oauth",
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "authentication_method": "oidc",
        "oidc_issuer_endpoint": "https://example.com/auth/realms/apicast",
        "policy_chain": [
            { "name": "apicast.policy.jwt_parser",
                "configuration": {
                    "issuer_endpoint": "http://test_backend:$TEST_NGINX_SERVER_PORT/realm" } },
            { "name": "apicast.policy.echo" }
         ]
      }
    }
  ]
}
--- request
GET /echo
--- more_headers eval
use Crypt::JWT qw(encode_jwt);
my $jwt = encode_jwt(payload => {
  aud => 'the_token_audience',
  sub => 'someone',
  iss => 'https://example.com/auth/realms/apicast',
  exp => time + 3600 }, key => \$::rsa, alg => 'RS256', extra_headers => { kid => 'somekid' });
"Authorization: Bearer $jwt"
--- error_code: 200
--- response_body
GET /echo HTTP/1.1
--- error_log
jwt_parser is incompatible with OIDC authentication mode

