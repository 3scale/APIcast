use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";
$ENV{APICAST_POLICY_LOAD_PATH} = 't/fixtures/policies';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: policy chain with a policy that crashes on new()
Policies that crash when initialized should be removed from the chain
--- configuration
{
    "services": [
      {
        "id": 42,
        "proxy": {
            "policy_chain" : [
              { "name" : "error_policy", "version" : "1.0.0" },
              { "name" : "apicast.policy.echo" } 
            ]
        }
      }
    ]
}
--- request
GET /test
--- response_body
GET /test HTTP/1.1
--- error_code: 200
--- error_log
Policy error_policy crashed in .new()
