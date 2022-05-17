use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{TEST_NGINX_REDIS_HOST} ||= $ENV{REDIS_HOST} || "127.0.0.1";
$ENV{TEST_NGINX_REDIS_PORT} ||= $ENV{REDIS_PORT} || 6379;
$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";

our $private_key = `cat t/fixtures/rsa.pem`;
our $public_key = `cat t/fixtures/rsa.pub`;

repeat_each(1);
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: Delay (conn) service scope.
Return 200 code.
--- configuration
{
  "services" : [
    {
      "id" : 2,
      "backend_version": 1,
      "proxy" : {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "hosts": ["flush.redis"]
      }
    },
    {
      "id" : 42,
      "backend_version" : 1,
      "proxy" : {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain" : [
          {
            "name" : "apicast.policy.rate_limit",
            "configuration" : {
              "connection_limiters" : [
                {
                  "key" : {"name" : "test2", "scope" : "service"},
                  "conn" : 1,
                  "burst" : 1,
                  "delay" : 2
                }
              ],
              "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
            }
          },{
            "name" : "apicast.policy.rate_limit",
            "configuration" : {
              "connection_limiters" : [
                {
                  "key" : {"name" : "test2", "scope" : "service"},
                  "conn" : 1,
                  "burst" : 1,
                  "delay" : 2
                }
              ],
              "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
            }
          },
          { "name": "apicast.policy.apicast" }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          redis:del('connections_test1')
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=value"]
--- error_code eval
[200, 200]
--- no_error_log
[error]
--- error_log
need to delay by


=== TEST 2: Delay (conn) default service scope.
Return 200 code.
--- configuration
{
  "services" : [
    {
      "id" : 2,
      "backend_version": 1,
      "proxy" : {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "hosts": ["flush.redis"]
      }
    },
    {
      "id" : 42,
      "backend_version" : 1,
      "proxy" : {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain" : [
          {
            "name" : "apicast.policy.rate_limit",
            "configuration" : {
              "connection_limiters" : [
                {
                  "key" : {"name" : "test2"},
                  "conn" : 1,
                  "burst" : 1,
                  "delay" : 2
                }
              ],
              "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
            }
          },{
            "name" : "apicast.policy.rate_limit",
            "configuration" : {
              "connection_limiters" : [
                {
                  "key" : {"name" : "test2"},
                  "conn" : 1,
                  "burst" : 1,
                  "delay" : 2
                }
              ],
              "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
            }
          },
          { "name": "apicast.policy.apicast" }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          redis:del('connections_test2')
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=value"]
--- error_code eval
[200, 200]
--- no_error_log
[error]
--- error_log
need to delay by


=== TEST 3: Invalid redis url.
Return 500 code.
--- configuration
{
  "services" : [
    {
      "id" : 42,
      "proxy" : {
        "policy_chain" : [
          {
            "name" : "apicast.policy.rate_limit",
            "configuration" : {
              "connection_limiters" : [
                {
                  "key" : {"name" : "test3", "scope" : "global"},
                  "conn" : 20,
                  "burst" : 10,
                  "delay" : 0.5
                }
              ],
              "redis_url" : "redis://invalidhost:$TEST_NGINX_REDIS_PORT/1"
            }
          }
        ]
      }
    }
  ]
}
--- request
GET /
--- error_code: 500
--- no_error_log
[error]
--- error_log
query for invalidhost finished with no answers


=== TEST 4: Rejected (conn) logging only.
Return 200 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test4", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 0,
                      "delay" : 2
                    },
                    {
                      "key" : {"name" : "test4", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 0,
                      "delay" : 2
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1",
                  "limits_exceeded_error" : { "error_handling" : "log" }
                }
              }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          redis:del('connections_test7')
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=foo","GET /?user_key=foo"]
--- error_code eval
[200, 200, 200]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 5: No redis url.
Return 200 code.
--- configuration
{
  "services" : [
    {
      "id" : 2,
      "backend_version": 1,
      "proxy" : {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "hosts": ["flush.limiter"]
      }
    },
    {
      "id" : 42,
      "proxy" : {
        "policy_chain" : [
          {
            "name" : "apicast.policy.rate_limit",
            "configuration" : {
              "connection_limiters" : [
                {
                  "key" : {"name" : "test5", "scope" : "global"},
                  "conn" : 20,
                  "burst" : 10,
                  "delay" : 0.5
                }
              ]
            }
          }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- request eval
["GET http://flush.limiter/flush?user_key=foo", "GET /?user_key=foo"]
--- error_code eval 
[200, 200]
--- no_error_log
[error]


=== TEST 6: Success with multiple limiters.
Return 200 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "backend_version" : 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
            ],
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "leaky_bucket_limiters" : [
                    {
                      "key" : {"name" : "test6_1", "scope" : "global"},
                      "rate" : 20,
                      "burst" : 10
                    }
                  ],
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test6_2", "scope" : "global"},
                      "conn" : 20,
                      "burst" : 10,
                      "delay" : 0.5
                    }
                  ],
                  "fixed_window_limiters" : [
                    {
                      "key" : {"name" : "test6_3", "scope" : "global"},
                      "count" : 20,
                      "window" : 10
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
                }
              },
              { "name": "apicast.policy.apicast" }
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
    location /flush {
      content_by_lua_block {
        local redis = require('apicast.threescale_utils').connect_redis({
           host = "$TEST_NGINX_REDIS_HOST",
           port = "$TEST_NGINX_REDIS_PORT",
           db=1})
        local redis_key = redis:keys('*_fixed_window_test6_3')[1]
        redis:del('leaky_bucket_test6_1', 'connections_test6_2', redis_key)
      }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=value"]
--- error_code eval
[200, 200]
--- no_error_log
[error]
need to delay by


=== TEST 7: Rejected (conn).
Return 429 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test7", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 0,
                      "delay" : 2
                    },
                    {
                      "key" : {"name" : "test7", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 0,
                      "delay" : 2
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
                }
              }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          redis:del('connections_test7')
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=foo","GET /?user_key=foo"]
--- error_code eval
[200, 429, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 8: Rejected (req).
Return 503 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "leaky_bucket_limiters" : [
                    {
                      "key" : {"name" : "test8", "scope" : "global"},
                      "rate" : 1,
                      "burst" : 0
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1",
                  "limits_exceeded_error" : { "status_code" : 503 }
                }
              }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          redis:del('leaky_bucket_test8')
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=foo","GET /?user_key=foo"]
--- error_code eval
[200, 200, 503]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 9: Rejected (count).
Return 429 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "fixed_window_limiters" : [
                    {
                      "key" : {"name" : "test9", "scope" : "global"},
                      "count" : 1,
                      "window" : 10
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1",
                  "limits_exceeded_error" : { "status_code" : 429 }
                }
              }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          local redis_key = redis:keys('*_fixed_window_test9')[1]
          redis:del(redis_key)
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=foo","GET /?user_key=foo"]
--- error_code eval
[200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 10: Delay (conn).
Return 200 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test10", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 1,
                      "delay" : 2
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
                }
              },
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test10", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 1,
                      "delay" : 2
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
                }
              }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          redis:del('connections_test10')
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=foo"]
--- error_code eval
[200, 200]
--- no_error_log
[error]


=== TEST 11: Delay (req).
Return 200 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "leaky_bucket_limiters" : [
                    {
                      "key" : {"name" : "test11", "scope" : "global"},
                      "rate" : 1,
                      "burst" : 1
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1"
                }
              }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          redis:del('leaky_bucket_test11')
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo","GET /?user_key=foo","GET /?user_key=foo"]
--- error_code eval
[200, 200, 200]
--- no_error_log
[error]


=== TEST 12: Rejected (conn) (no redis).
Return 429 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.limiter"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test12", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 0,
                      "delay" : 2
                    }
                  ]
                }
              },
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test12", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 0,
                      "delay" : 2
                    }
                  ]
                }
              }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- pipelined_requests eval
["GET http://flush.limiter/flush?user_key=foo", "GET /?user_key=foo"]
--- error_code eval
[200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 13: Rejected (req) (no redis).
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.limiter"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "leaky_bucket_limiters" : [
                    {
                      "key" : {"name" : "test13", "scope" : "global"},
                      "rate" : 1,
                      "burst" : 0
                    }
                  ],
                  "limits_exceeded_error" : { "error_handling" : "exit" }
                }
              }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- pipelined_requests eval
["GET http://flush.limiter/flush?user_key=foo", "GET /?user_key=foo", "GET /?user_key=foo"]
--- error_code eval 
[200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 14: Rejected (count) (no redis).
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.limiter"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "fixed_window_limiters" : [
                    {
                      "key" : {"name" : "test14", "scope" : "global"},
                      "count" : 1,
                      "window" : 10
                    }
                  ]
                }
              }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- pipelined_requests eval
["GET http://flush.limiter/flush?user_key=foo", "GET /?user_key=foo", "GET /?user_key=foo"]
--- error_code eval 
[200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 15: Delay (conn) (no redis).
Return 200 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.limiter"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test15", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 1,
                      "delay" : 2
                    }
                  ]
                }
              },
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "connection_limiters" : [
                    {
                      "key" : {"name" : "test15", "scope" : "global"},
                      "conn" : 1,
                      "burst" : 1,
                      "delay" : 2
                    }
                  ]
                }
              }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- pipelined_requests eval
["GET http://flush.limiter/flush?user_key=foo", "GET /?user_key=foo"]
--- error_code eval 
[200, 200]
--- no_error_log
[error]
--- error_log
need to delay by


=== TEST 16: Delay (req) (no redis).
Return 200 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.limiter"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "leaky_bucket_limiters" : [
                    {
                      "key" : {"name" : "test16", "scope" : "global"},
                      "rate" : 1,
                      "burst" : 1
                    }
                  ]
                }
              }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- pipelined_requests eval
["GET http://flush.limiter/flush?user_key=foo", "GET /?user_key=foo", "GET /?user_key=foo"]
--- error_code eval 
[200, 200, 200]
--- no_error_log
[error]


=== TEST 17: Liquid templating (jwt.aud).
Rate Limit policy accesses to the jwt
which the apicast policy stores to the context.
This test uses "jwt.aud" as key name.
This test calls the service 3 times,
and the second call has a different jwt.aud,
so only the third call returns 429.
--- configuration env eval

use JSON qw(to_json);

to_json({
  services => [{
    id => 2,
    backend_version => 1,
    proxy => {
      api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
      proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
      ],
      hosts => ["flush.redis"]
    }
  },
  {
    id => 42,
    backend_version => 'oauth',
    backend_authentication_type => 'provider_key',
    proxy => {
      authentication_method => 'oidc',
      oidc_issuer_endpoint => 'https://example.com/auth/realms/apicast',
      api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
      proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
      ],
      policy_chain => [
        {
          name => "apicast.policy.rate_limit",
          configuration => {
            fixed_window_limiters => [
              {
                key => {name => "{{jwt.aud}}", scope => "global", name_type => "liquid"},
                count => 1,
                window => 10
              }
            ],
            redis_url => "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1",
            limits_exceeded_error => { status_code => 429 }
          }
        },
        {name => "apicast.policy.apicast"}
      ]
    }
  }
  ],
    oidc => [{},{
    issuer => 'https://example.com/auth/realms/apicast',
    config => { id_token_signing_alg_values_supported => [ 'RS256' ] },
    keys => { somekid => { pem => $::public_key, alg => 'RS256' } },
  }]
});
--- backend
location /transactions/authrep.xml {
  content_by_lua_block {
    ngx.exit(200)
  }
}
location /transactions/oauth_authrep.xml {
  content_by_lua_block {
    ngx.exit(200)
  }
}
--- upstream env
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          local redis_key1 = redis:keys('*_fixed_window_test17_1')[1]
          local redis_key2 = redis:keys('*_fixed_window_test17_2')[1]
          redis:del(redis_key1, redis_key2)
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo", "GET /", "GET /", "GET /"]
--- more_headers eval
use Crypt::JWT qw(encode_jwt);
my $jwt1 = encode_jwt(payload => {
  aud => 'test17_1',
  sub => 'someone',
  iss => 'https://example.com/auth/realms/apicast',
  exp => time + 3600 }, key => \$::private_key, alg => 'RS256', extra_headers => { kid => 'somekid' });
my $jwt2 = encode_jwt(payload => {
  aud => 'test17_2',
  sub => 'someone',
  iss => 'https://example.com/auth/realms/apicast',
  exp => time + 3600 }, key => \$::private_key, alg => 'RS256', extra_headers => { kid => 'somekid' });
["Authorization: Bearer $jwt1", "Authorization: Bearer $jwt1", "Authorization: Bearer $jwt2", "Authorization: Bearer $jwt1"]
--- error_code eval 
[200, 200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 18: Liquid templating (ngx.***).
This test uses "ngx.var.host" and "ngx.var.uri" as key name.
This test calls the service 3 times,
and the second call has a different ngx.var.uri,
so only the third call returns 429.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "fixed_window_limiters" : [
                    {
                      "key" : {"name" : "{{host}}{{uri}}", "scope" : "global", "name_type" : "liquid"},
                      "count" : 1,
                      "window" : 10
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1",
                  "limits_exceeded_error" : { "status_code" : 429 }
                }
              }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          local redis_key1 = redis:keys('*_fixed_window_localhost/test18_1')[1]
          local redis_key2 = redis:keys('*_fixed_window_localhost/test18_2')[1]
          redis:del(redis_key1, redis_key2)
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo", "GET /test18_1?user_key=foo", "GET /test18_2?user_key=foo", "GET /test18_1?user_key=foo"]
--- error_code eval 
[200, 200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 19: Rejected (count). Using multiple limiters of the same type.
To confirm that multiple limiters of the same type are configurable
and rejected properly.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.redis"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "fixed_window_limiters" : [
                    {
                      "key" : {"name" : "{{host}}", "name_type" : "liquid"},
                      "count" : 2,
                      "window" : 10
                    },
                    {
                      "key" : {"name" : "{{uri}}", "name_type" : "liquid"},
                      "count" : 1,
                      "window" : 10
                    }
                  ],
                  "redis_url" : "redis://$TEST_NGINX_REDIS_HOST:$TEST_NGINX_REDIS_PORT/1",
                  "limits_exceeded_error" : { "status_code" : 429 }
                }
              }
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
    location /flush {
        content_by_lua_block {
          local redis = require('apicast.threescale_utils').connect_redis({
             host = "$TEST_NGINX_REDIS_HOST",
             port = "$TEST_NGINX_REDIS_PORT",
             db = 1})
          redis:flushdb()
        }
    }
--- pipelined_requests eval
["GET http://flush.redis/flush?user_key=foo", "GET /test19_1?user_key=foo", "GET /test19_2?user_key=foo", "GET /test19_3?user_key=foo"]
--- error_code eval 
[200, 200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 20: with conditions
We define a limit of 1 with a false condition, and a limit of 2 with a
condition that's true. We check that the false condition does not apply by
making 3 requests and checking that only the last one is rejected.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.limiter"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "fixed_window_limiters" : [
                    {
                      "key" : {"name" : "test20_key_1"},
                      "count" : 2,
                      "window" : 10,
                      "condition" : {
                        "operations" : [
                          {
                            "left" : "{{ uri }}",
                            "left_type" : "liquid",
                            "op" : "==",
                            "right" : "/"
                          }
                        ]
                      }
                    },{
                      "key" : {"name" : "test20_key_2"},
                      "count" : 1,
                      "window" : 10,
                      "condition" : {
                        "operations" : [
                          {
                            "left" : "1",
                            "op" : "==",
                            "right" : "2"
                          }
                        ]
                      }
                    }
                  ],
                  "limits_exceeded_error" : { "status_code" : 429 }
                }
              }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- pipelined_requests eval
["GET http://flush.limiter/flush?user_key=foo", "GET /?user_key=foo", "GET /?user_key=foo", "GET /?user_key=foo"]
--- error_code eval 
[200, 200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 21: condition with "matches" operation
This test makes 3 requests that match the URL pattern defined in the
limit. The limit is set to 2. Only the third one should fail.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.limiter"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "fixed_window_limiters" : [
                    {
                      "key" : {"name" : "test21_key_1"},
                      "count" : 2,
                      "window" : 60,
                      "condition" : {
                        "operations" : [
                          {
                            "left" : "{{ uri }}",
                            "left_type" : "liquid",
                            "op" : "matches",
                            "right" : "/v1/.*/something/.*"
                          }
                        ]
                      }
                    }
                  ],
                  "limits_exceeded_error" : { "status_code" : 429 }
                }
              }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- pipelined_requests eval
["GET http://flush.limiter/flush?user_key=foo", "GET /v1/aaa/something/bbb?user_key=foo", "GET /v1/ccc/something/ddd?user_key=foo", "GET /v1/eee/something/fff?user_key=foo"]
--- error_code eval 
[200, 200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.


=== TEST 22: Window is set to 0 and default is 1.
Return 429 code.
--- configuration
    {
      "services" : [
        {
          "id" : 2,
          "backend_version": 1,
          "proxy" : {
            "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
            "proxy_rules": [
              { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
            ],
            "hosts": ["flush.limiter"]
          }
        },
        {
          "id" : 42,
          "proxy" : {
            "policy_chain" : [
              {
                "name" : "apicast.policy.rate_limit",
                "configuration" : {
                  "fixed_window_limiters" : [
                    {
                      "key" : {"name" : "test22"},
                      "count" : 1,
                      "window" : 0
                    }
                  ],
                  "limits_exceeded_error" : { "status_code" : 429 }
                }
              }
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
    location /flush {
      content_by_lua_block {
        require "resty.core"
        ngx.shared.limiter:flush_all()
      }
    }
--- pipelined_requests eval
["GET http://flush.limiter/flush?user_key=foo", "GET /?user_key=foo", "GET /?user_key=foo"]
--- error_code eval 
[200, 200, 429]
--- no_error_log
[error]
--- error_log
Requests over the limit.
