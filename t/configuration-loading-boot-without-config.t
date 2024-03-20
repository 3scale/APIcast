use lib 't';
use Test::APIcast::Blackbox 'no_plan';

env_to_apicast(
    'APICAST_CONFIGURATION_LOADER' => 'boot'
);

log_level('emerg');
run_tests();

__DATA__

=== TEST 1: require configuration on boot
should exit with error if there is no configuration
--- must_die
--- error_log
failed to load configuration, exiting
