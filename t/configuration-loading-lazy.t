use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{TEST_NGINX_HTTP_CONFIG} = "$Test::APIcast::path/http.d/init.conf";
$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";
$ENV{APICAST_CONFIGURATION_LOADER} = 'lazy';

repeat_each(1);

run_tests();

__DATA__

=== TEST 1: load empty configuration
should just say service is not found
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream
location /admin/api/services.json {
    echo '{}';
}
--- request: GET /t
--- error_code: 404
--- error_log
service not found for host localhost
using lazy configuration loader

=== TEST 2: load invalid configuration
should fail with server error
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream
location /admin/api/services.json {
    echo '';
}
--- request: GET /t
--- error_code: 404
--- error_log
service not found for host localhost
using lazy configuration loader

=== TEST 3: load valid configuration
should correctly route the request
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
    location = /admin/api/services.json {
        echo '
        {
            "services": [
                { "service": { "id":1 } }
            ]
        }';
    }

    location = /admin/api/services/1/proxy/configs/production/latest.json {
        echo '
        {
            "proxy_config": {
                "content": {
                    "id": 1,
                    "backend_version": 1,
                    "proxy": {
                        "hosts": [ "localhost" ],
                        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
                        "proxy_rules": [
                            { "pattern": "/t", "http_method": "GET", "metric_system_name": "test","delta": 1 }
                        ]
                    }
                }
            }
        }';
    }

    location /t {
        echo "all ok";
    }

--- backend
    location /transactions/authrep.xml {
      content_by_lua_block {
        ngx.exit(200)
      }
    }
--- request
GET /t?user_key=fake
--- error_code: 200
--- error_log
using lazy configuration loader
--- no_error_log
[error]

=== TEST 4: load invalid json
To validate that process does not died with invalid config
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream
location ~ /admin/(.+) {
    echo '{Hello, world}';
}
--- request
GET /t?user_key=fake
--- error_code: 404
--- no_error_log
[error]

=== TEST 5: load invalid oidc target url
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
    location = /admin/api/services.json {
        echo '
        {
            "services": [
                { "service": { "id":1 } }
            ]
        }';
    }

    location = /admin/api/services/1/proxy/configs/production/latest.json {
        echo '
        {
            "proxy_config": {
                "content": {
                    "id": 1,
                    "backend_version": "oauth",
                    "proxy": {
                        "hosts": [ "localhost" ],
                        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
                        "service_id": 2555417794444,
                        "oidc_issuer_endpoint": "www.fgoodl/adasd",
                        "authentication_method": "oidc",
                        "service_backend_version": "oauth",
                        "proxy_rules": [
                            { "pattern": "/t", "http_method": "GET", "metric_system_name": "test","delta": 1 }
                        ]
                    }
                }
            }
        }';
    }
--- backend
    location /transactions/authrep.xml {
      content_by_lua_block {
        ngx.exit(200)
      }
    }
--- request
GET /t?user_key=fake
--- error_code: 401
--- error_log
using lazy configuration loader
OIDC url is not valid, uri:
--- no_error_log
[error]
