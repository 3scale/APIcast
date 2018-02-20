use lib 't';
use Test::APIcast::Blackbox 'no_plan';

env_to_apicast(
    'APICAST_PROXY_HTTPS_CERTIFICATE' => "$Test::Nginx::Util::ServRoot/html/client.crt",
    'APICAST_PROXY_HTTPS_CERTIFICATE_KEY' => "$Test::Nginx::Util::ServRoot/html/client.key",
);

run_tests();

__DATA__
=== TEST 1: mutual SSL
--- ssl random_port
--- configuration
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
ssl_client_s_dn: O=Internet Widgits Pty Ltd,ST=Some-State,C=AU
ssl_client_i_dn: O=Internet Widgits Pty Ltd,ST=Some-State,C=AU
--- error_code: 200
--- no_error_log
[error]
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIB0DCCAXegAwIBAgIJAISY+WDXX2w5MAoGCCqGSM49BAMCMEUxCzAJBgNVBAYT
AkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
aXRzIFB0eSBMdGQwHhcNMTYxMjIzMDg1MDExWhcNMjYxMjIxMDg1MDExWjBFMQsw
CQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhkmo
6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1cbx0wVEzbYK5wRb7U
iWhvvvYDltIzsD75vqNQME4wHQYDVR0OBBYEFOBBS7ZF8Km2wGuLNoXFAcj0Tz1D
MB8GA1UdIwQYMBaAFOBBS7ZF8Km2wGuLNoXFAcj0Tz1DMAwGA1UdEwQFMAMBAf8w
CgYIKoZIzj0EAwIDRwAwRAIgZ54vooA5Eb91XmhsIBbp12u7cg1qYXNuSh8zih2g
QWUCIGTHhoBXUzsEbVh302fg7bfRKPCi/mcPfpFICwrmoooh
-----END CERTIFICATE-----
>>> server.key
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIFCV3VwLEFKz9+yTR5vzonmLPYO/fUvZiMVU1Hb11nN8oAoGCCqGSM49
AwEHoUQDQgAEhkmo6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1c
bx0wVEzbYK5wRb7UiWhvvvYDltIzsD75vg==
-----END EC PRIVATE KEY-----
>>> client.crt
-----BEGIN CERTIFICATE-----
MIICWDCCAcGgAwIBAgIJAN52KeMKGGq9MA0GCSqGSIb3DQEBBQUAMEUxCzAJBgNV
BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
aWRnaXRzIFB0eSBMdGQwHhcNMTgwMjE5MTQ0MzE4WhcNMTkwMjE5MTQ0MzE4WjBF
MQswCQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50
ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKB
gQC7b4gs1UsUI1akyeUdCF8RMHQhjf9XKMwGTc85RML+cLEl5MASYCOC5iE5/9Rv
hLcgcRdJr1A/blLhK1NZOPVzI9fYFn5zTjxG94Pv11kIcvYLoJeZT1zlvCBsz2Ak
tzK31QRXvkpn3ZikUQVflV5ArzFrIdxPNelVDMk1dwBejwIDAQABo1AwTjAdBgNV
HQ4EFgQUoZwBPUe+E0r8/UTPJtJzntVvx44wHwYDVR0jBBgwFoAUoZwBPUe+E0r8
/UTPJtJzntVvx44wDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOBgQBjVV6h
fhZCNpzu9odus6uXiTGjAm2FJlpncxPw9lseKLljy2hm4dq94GYr1gFoMR7KmE+k
Bp1RMO59vZd7TtrQ4d2t898mif04CCiQz1BeJ3cSvE+vhHJLmL+ImHh9uKFdmcg6
MT5sX28flpZvErxsqjJ/bhKyd2R+WVuYWaoyfw==
-----END CERTIFICATE-----
>>> client.key
-----BEGIN RSA PRIVATE KEY-----
MIICXgIBAAKBgQC7b4gs1UsUI1akyeUdCF8RMHQhjf9XKMwGTc85RML+cLEl5MAS
YCOC5iE5/9RvhLcgcRdJr1A/blLhK1NZOPVzI9fYFn5zTjxG94Pv11kIcvYLoJeZ
T1zlvCBsz2AktzK31QRXvkpn3ZikUQVflV5ArzFrIdxPNelVDMk1dwBejwIDAQAB
AoGBALZHctDW5NrCuyIqzct8NqfKzUVMiINEw5Vl2h7BhjhXc498dGXqZN6J2spC
x19kW4sLMDCSc6IcMjGUJsxgHiGecloLHYnFz4faJpgNMjpu0vmz66qy/QnCy5Rf
/g5mtQUhEkpivi9q4Thqxc2v8Y3g95D4boYYX7qNRq9jX52BAkEA6EMZOErUGIot
vOAYSSOtkqE6di3gVqVaSk2kHjujO5AMcjhTiNv5bMrPUEOfR+JQE97XSqymfWdg
TT7YvDt1bwJBAM6XmHA56qE7wpL9SwERlXOX/4fiTRzWDXEL+htoErMPYs/aPume
NJBXLoTfgUghAKvhsUyMSCv/EHenGl+gWOECQQCII3xO4J19XND+WqQhisYcomBw
EOfkIbvQvb2q8u305bRF5vofyEBlImNt+pUMP30MiJvM63ITI1rxLBtCCeAFAkA2
Fk5co20gRUsNvK7UWswr9VF7O+5AbHIcdKxIXJj4tECEdnkeJMNSPuD4/KMWRT2t
wmruxZNnoWGoUeF/w7VBAkEAz02rLKfeCShkbJd5f0qx0cubG/2lznrMvSBoI2ix
itRV3G/wOHrsK9k06jx2L/+/YTUWcyzTm8B7Y34CTHGaHQ==
-----END RSA PRIVATE KEY-----
