use lib 't';
use Test::APIcast::Blackbox 'no_plan';

$ENV{TEST_NGINX_HTTP_CONFIG} = "$Test::APIcast::path/http.d/*.conf";

repeat_each(1);

master_on();
log_level('warn');
run_tests();

__DATA__

=== TEST 1: uses all resolvers
both RESOLVER env variable and resolvers in resolv.conf should be used.
checking if commented 'nameserver' and 'search' keywords impact on the
resolv.conf file parsing.
--- env eval
('RESOLVER' => '127.0.1.1:5353',
'TEST_NGINX_RESOLV_CONF' => "$Test::Nginx::Util::HtmlDir/resolv.conf")
--- nameservers
nameservers = false,
--- configuration
{}
--- upstream
  location /t {
    content_by_lua_block {
      local nameservers = require('resty.resolver').nameservers()
      ngx.say('nameservers: ', #nameservers, ' ', nameservers[1], ' ', nameservers[2], ' ', nameservers[3])
    }
  }
--- upstream_name
t
--- more_headers
Host: t
--- request
GET /t
--- response_body
nameservers: 3 127.0.1.15353 1.2.3.453 4.5.6.753
--- user_files
>>> resolv.conf
# nameserver updated  in comentary
#nameserver updated  in comentary
#comentary nameserver 1.2.3.4
#comentary nameserver
# search updated.example.com  in comentary
#search updated  in comentary
#search nameserver 1.2.3.4
#search nameserver
search localdomain.example.com local #search nameserver
nameserver 1.2.3.4  #search nameserver
nameserver 4.5.6.7  #nameserver search

=== TEST 2: uses upstream peers
When upstream is defined with the same name use its peers.
--- configuration
{}
--- sites_d
upstream some_name {
  server 1.2.3.4:5678;
  server 2.3.4.5:6789;
}
--- upstream
  location = /t {
    content_by_lua_block {
      local resolver = require('resty.resolver'):instance()
      local servers = resolver:get_servers('some_name')

      ngx.say('servers: ', #servers)
      for i=1, #servers do
        ngx.say(servers[i].address, ':', servers[i].port)
      end
    }
  }
--- upstream_name
t
--- more_headers
Host: t
--- request
GET /t
--- response_body
servers: 2
1.2.3.4:5678
2.3.4.5:6789
--- no_error_log
[error]

=== TEST 3: can have ipv6 RESOLVER
RESOLVER env variable can be IPv6 address
--- env eval
('RESOLVER' => '[dead::beef]:5353',
'TEST_NGINX_RESOLV_CONF' => "$Test::Nginx::Util::HtmlDir/resolv.conf")
--- configuration
{}
--- upstream_name
t
--- upstream
  location = /t {
    content_by_lua_block {
      local nameservers = require('resty.resolver').nameservers()
      ngx.say('nameservers: ', #nameservers, ' ', tostring(nameservers[1]))
    }
  }
--- more_headers
Host: t
--- request
GET /t
--- response_body
nameservers: 1 [dead::beef]:5353
--- user_files
>>> resolv.conf


=== TEST 4: do not duplicate nameserver from RESOLVER
nameservers should not repeat if already configured
--- env eval
('RESOLVER' => '127.0.1.1:53',
'TEST_NGINX_RESOLV_CONF' => "$Test::Nginx::Util::HtmlDir/resolv.conf")
--- configuration
{}
--- upstream
  location = /t {
    content_by_lua_block {
      local nameservers = require('resty.resolver').nameservers()
      ngx.say('nameservers: ', #nameservers, ' ', nameservers[1], ' ', nameservers[2])
    }
  }
--- upstream_name
t
--- more_headers
Host: t
--- request
GET /t
--- response_body
nameservers: 2 127.0.1.153 1.2.3.453
--- user_files
>>> resolv.conf
nameserver 127.0.1.1
nameserver 1.2.3.4
