local _M = require 'apicast.configuration_loader.remote_v2'
local test_backend_client = require 'resty.http_ng.backend.test'
local cjson = require 'cjson'
local user_agent = require 'apicast.user_agent'
local env = require 'resty.env'

local service_generator = function(n)
  local services = {}
  for i = 1,n,1 do
    services[i] = { service = { id = 1 } }
  end

  return { services = services }
end

local proxy_config_generator = function(n)
  local proxy_configs = {}
  for i = 1,n do
    proxy_configs[i] = { proxy_config = {
      version = 42,
      environment = 'staging',
      content = { id = 2, backend_version = 2 }
    }}
  end

  return { proxy_configs = proxy_configs }
end

describe('Configuration Remote Loader V2', function()

  local test_backend
  local loader

  before_each(function() test_backend = test_backend_client.new() end)
  before_each(function()
    loader = _M.new('http://example.com', { client = test_backend })
  end)

  after_each(function() test_backend.verify_no_outstanding_expectations() end)

  describe('loader without endpoint', function()
    before_each(function() loader = _M.new() end)

    it('wont crash when getting services', function()
      assert.same({ nil, 'no endpoint' }, { loader:services() })
    end)

    it('wont crash when getting config', function()
      assert.same({ nil, 'no endpoint' }, { loader:config() })
    end)
  end)

  describe('http_client #http', function()
    it('has correct user agent', function()
      test_backend.expect{ url = 'http://example.com/t', headers = { ['User-Agent'] = tostring(user_agent) } }
        .respond_with{ status = 200  }

      local res, err = loader.http_client.get('http://example.com/t')

      assert.falsy(err)
      assert.equal(200, res.status)
    end)
  end)

  describe(':services', function()
    it('retuns list of services', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode({ services = {
            { service = { id = 1 }},
            { service = { id = 2 }}
          }})
        }

      local services = loader:services()

      assert.truthy(services)
      assert.equal(2, #services)
    end)

    it('returns list of services when APICAST_SERVICES_LIST is set', function()
      env.set('APICAST_SERVICES_LIST', '11,42')

      local services = loader:services()

      assert.truthy(services)
      assert.equal(2, #services)
      assert.same({ { service = { id = 11 } }, { service = { id = 42 } } }, services)
    end)

    it('returns list of services when APICAST_SERVICES is set', function()
      env.set('APICAST_SERVICES', '11,42')

      local services = loader:services()

      assert.truthy(services)
      assert.equal(2, #services)
      assert.same({ { service = { id = 11 } }, { service = { id = 42 } } }, services)
    end)

    it('ignores APICAST_SERVICES_LIST when empty', function()
      env.set('APICAST_SERVICES_LIST', '')

      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode({ services = { { service = { id = 1 }} }}) }

      local services = loader:services()

      assert.truthy(services)
      assert.equal(1, #services)
      assert.same({ { service = { id = 1 } } }, services)
    end)

    it('ignores APICAST_SERVICES when empty', function()
      env.set('APICAST_SERVICES', '')

      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode({ services = { { service = { id = 1 }} }}) }

      local services = loader:services()

      assert.truthy(services)
      assert.equal(1, #services)
      assert.same({ { service = { id = 1 } } }, services)
    end)

    it('ignores APICAST_SERVICES when empty and returns a list of services when APICAST_SERVICES_LIST is set', function()
      env.set('APICAST_SERVICES', '')
      env.set('APICAST_SERVICES_LIST', '11,42')

      local services = loader:services()

      assert.truthy(services)
      assert.equal(2, #services)
      assert.same({ { service = { id = 11 } }, { service = { id = 42 } } }, services)
    end)

    it('ignores APICAST_SERVICES_LIST when empty and returns a list of services when APICAST_SERVICES is set', function()
      env.set('APICAST_SERVICES_LIST', '')
      env.set('APICAST_SERVICES', '11,42')

      local services = loader:services()

      assert.truthy(services)
      assert.equal(2, #services)
      assert.same({ { service = { id = 11 } }, { service = { id = 42 } } }, services)
    end)

    it('retuns list of services with multiple pages', function()
      -- Will serve: 3 pages
      -- page 1 => SERVICES_PER_PAGE
      -- page 2 => SERVICES_PER_PAGE
      -- page 3 => 51
      local SERVICES_PER_PAGE = 500
      local page1 = service_generator(SERVICES_PER_PAGE)
      local page2 = service_generator(SERVICES_PER_PAGE)
      local page3 = service_generator(51)

      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode(page1) }

      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 2 })}.
        respond_with{ status = 200, body = cjson.encode(page2) }

      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 3 })}.
        respond_with{ status = 200, body = cjson.encode(page3) }

      local services = loader:services()

      assert.truthy(services)
      assert.equal(2*SERVICES_PER_PAGE + 51, #services)
    end)

    it('does not crash on error when getting services', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 404 }

      local services, err = loader:services()

      assert.falsy(services)
      assert.equal('invalid status: 404 (Not Found)', tostring(err))
    end)

    it('returns nil and an error if the response body is not a valid', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
      respond_with{ status = 200, body = '{ invalid json }'}

      local services, err = loader:services()
      assert.falsy(services)
      assert.equals('Expected object key string but found invalid token at character 3', err)
    end)
  end)

  describe(':config', function()
    it('loads a configuration', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services/42/proxy/configs/sandbox/latest.json' }.
        respond_with{ status = 200, body = cjson.encode(
          {
            proxy_config = {
              version = 13,
              environment = 'sandbox',
              content = { id = 42, backend_version = 1, proxy = { oidc_issuer_endpoint = ngx.null } }
            }
          }
        ) }
      local service = { id = 42 }

      local config = loader:config(service, 'sandbox', 'latest')

      assert.truthy(config)
      assert.equal('table', type(config.content))
      assert.equal(13, config.version)
      assert.equal('sandbox', config.environment)
    end)

    it('takes version from the environment', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services/42/proxy/configs/sandbox/2.json' }.
      respond_with{ status = 200, body = cjson.encode(
        {
          proxy_config = {
            version = 2,
            environment = 'sandbox',
            content = { id = 42, backend_version = 1 }
          }
        }
      ) }
      local service = { id = 42 }

      env.set('APICAST_SERVICE_42_CONFIGURATION_VERSION', '2')
      local config = loader:config(service, 'sandbox', 'latest')

      assert.truthy(config)
      assert.equal('table', type(config.content))
      assert.equal(2, config.version)
      assert.equal('sandbox', config.environment)
    end)

    it('includes OIDC configuration', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services/42/proxy/configs/staging/latest.json' }.
      respond_with{ status = 200, body = cjson.encode(
              {
                proxy_config = {
                  version = 2,
                  environment = 'sandbox',
                  content = {
                    id = 42, backend_version = 1,
                    proxy = {
                      authentication_method= 'oidc',
                      oidc_issuer_endpoint = 'http://user:pass@idp.example.com/auth/realms/foo/'
                    }
                  }
                }
              }
      ) }

      test_backend.expect{ url = "http://idp.example.com/auth/realms/foo/.well-known/openid-configuration" }.
      respond_with{
        status = 200,
        headers = { content_type = 'application/json' },
        body = [[
            {
              "issuer": "https://idp.example.com/auth/realms/foo",
              "jwks_uri": "https://idp.example.com/auth/realms/foo/jwks",
              "id_token_signing_alg_values_supported": [ "RS256" ]
            }
          ]]
      }
      test_backend.expect{ url = "https://idp.example.com/auth/realms/foo/jwks" }.
      respond_with{
        status = 200,
        headers = { content_type = 'application/json' },
        body =  [[
            { "keys": [{
                "kid": "3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y",
                "kty": "RSA",
                "n": "iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw",
                "e": "AQAB"
            }] }
        ]]
      }

      local config = assert(loader:config({ id = 42 }, 'staging', 'latest'))

      assert.same({
        config = {
          id_token_signing_alg_values_supported = { 'RS256' },
          issuer = 'https://idp.example.com/auth/realms/foo',
          jwks_uri = 'https://idp.example.com/auth/realms/foo/jwks'
        },
        issuer = 'https://idp.example.com/auth/realms/foo',
        keys = { ['3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y'] = {
          e = 'AQAB',
          kid = '3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y',
          kty = 'RSA',
          n = 'iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw',
          pem = [[
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiqXwBiZgN2q1dCKU1P/v
zyiGacdQhfqgxQST7GFlWU/PUljV9uHrLOadWadpxRAuskNpXWsrKoU/hDxtSpUI
RJj6hL5YTlrvv+IbFwPNtD8LnOfKL043/ZdSOe3aT4R4NrBxUomndILUESlhqddy
lVMCGXQ81OB73muc9ovR68Ajzn8KzpU/qegh8iHwk+SQvJxIIvgNJCJTC6BWnwS9
Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG+fqUAPHy5IYQaD8k8QX
0obxJ0fld61fH+Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf+KrSagD5G
UwIDAQAB
-----END PUBLIC KEY-----
]],
        } },
      }, config.oidc)
    end)

    it('ingore OIDC configuration when authentication_method is not oidc', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services/42/proxy/configs/staging/latest.json' }.
      respond_with{ status = 200, body = cjson.encode(
              {
                proxy_config = {
                  version = 2,
                  environment = 'sandbox',
                  content = {
                    id = 42, backend_version = 1,
                    proxy = {
                      authentication_method= '1',
                      oidc_issuer_endpoint = 'http://user:pass@idp.example.com/auth/realms/foo/'
                    }
                  }
                }
              }
      ) }

      local config = assert(loader:config({ id = 42 }, 'staging', 'latest'))
      assert.is_nil(config.oidc)
    end)
  end)

  describe(':index_per_service', function()
    before_each(function()
      env.set('THREESCALE_DEPLOYMENT_ENV', 'staging')
    end)

    it('returns configuration for all services', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode({ services = {
            { service = { id = 1 }},
            { service = { id = 2 }}
          }})
        }
      test_backend.expect{ url = 'http://example.com/admin/api/services/1/proxy/configs/staging/latest.json' }.
        respond_with{ status = 200, body = cjson.encode(
          {
            proxy_config = {
              version = 13,
              environment = 'staging',
              content = { id = 1, backend_version = 1 }
            }
          }
        )}
      test_backend.expect{ url = 'http://example.com/admin/api/services/2/proxy/configs/staging/latest.json' }.
        respond_with{ status = 200, body = cjson.encode(
          {
            proxy_config = {
              version = 42,
              environment = 'staging',
              content = { id = 2, backend_version = 2 }
            }
          }
        )}

      local config = assert(loader:index_per_service())

      assert.truthy(config)
      assert.equals('string', type(config))

      assert.equals(2, #(cjson.decode(config).services))
    end)

    it('does not crash on error when getting services', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 404 }

      local config, err = loader:index_per_service()

      assert.falsy(config)
      assert.equal('invalid status: 404 (Not Found)', tostring(err))
    end)

    it('returns simple message on undefined errors', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
      respond_with{ status = 412 }

      local config, err = loader:index_per_service()

      assert.falsy(config)
      assert.equal('invalid status: 412', tostring(err))
    end)

    it('returns configuration even when some services are missing', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode({ services = {
            { service = { id = 1 }},
            { service = { id = 2 }}
          }})
        }
      test_backend.expect{ url = 'http://example.com/admin/api/services/1/proxy/configs/staging/latest.json' }.
        respond_with{ status = 200, body = cjson.encode(
          {
            proxy_config = {
              version = 13,
              environment = 'staging',
              content = { id = 1, backend_version = 1 }
            }
          }
        )}
      test_backend.expect{ url = 'http://example.com/admin/api/services/2/proxy/configs/staging/latest.json' }.
        respond_with{ status = 404 }

      local config = assert(loader:index_per_service())

      assert.truthy(config)
      assert.equals('string', type(config))

      assert.equals(1, #(cjson.decode(config).services))
    end)

    describe("When using APICAST_SERVICES_FILTER_BY_URL", function()
      before_each(function()
        test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
        ngx.encode_args({ per_page = 500, page = 1 })}.
          respond_with{ status = 200, body = cjson.encode({ services = {
              { service = { id = 1 }},
              { service = { id = 2 }}
            }})
          }

        test_backend.expect{ url = 'http://example.com/admin/api/services/1/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = cjson.encode(
            {
              proxy_config = {
                version = 13,
                environment = 'staging',
                content = {
                  id = 1,
                  backend_version = 1,
                  proxy = {
                    hosts = {"one.com", "first.dev"}
                  }
                }
              }
            }
          )}

        test_backend.expect{ url = 'http://example.com/admin/api/services/2/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = cjson.encode(
            {
              proxy_config = {
                version = 42,
                environment = 'staging',
                content = {
                  id = 2,
                  backend_version = 1,
                  proxy = {
                    hosts = {"two.com", "second.dev"}
                  }
                }
              }
            }
          )}
      end)

      it("Filter it out correctly", function()
        env.set('APICAST_SERVICES_FILTER_BY_URL','one.*')

        local config = assert(loader:index_per_service())

        assert.truthy(config)
        assert.equals('string', type(config))

        local res_services = cjson.decode(config).services
        assert.equals(1, #res_services)
        assert.equals(1, res_services[1].id)
      end)

      it("Filter it out correctly by prod host", function()
        env.set('APICAST_SERVICES_FILTER_BY_URL','*dev')

        local config = assert(loader:index_per_service())

        assert.truthy(config)
        assert.equals('string', type(config))

        local res_services = cjson.decode(config).services
        assert.equals(2, #res_services)
        assert.equals(1, res_services[1].id)
        assert.equals(2, res_services[2].id)
      end)

      it("Filter it out correctly multiple", function()

        env.set('APICAST_SERVICES_FILTER_BY_URL','*.com')

        local config = assert(loader:index_per_service())

        assert.truthy(config)
        assert.equals('string', type(config))

        local res_services = cjson.decode(config).services
        assert.equals(2, #res_services)
        assert.equals(1, res_services[1].id)
        assert.equals(2, res_services[2].id)
      end)

      it("NIL return all services", function()

        env.set('APICAST_SERVICES_FILTER_BY_URL','')

        local config = assert(loader:index_per_service())

        assert.truthy(config)
        assert.equals('string', type(config))

        local res_services = cjson.decode(config).services
        assert.equals(2, #res_services)
        assert.equals(1, res_services[1].id)
        assert.equals(2, res_services[2].id)
      end)

      it("invalid regexp return all", function()
        env.set('APICAST_SERVICES_FILTER_BY_URL','[')

        local config = assert(loader:index_per_service())

        assert.truthy(config)
        assert.equals('string', type(config))

        local res_services = cjson.decode(config).services
        assert.equals(2, #res_services)
        assert.equals(1, res_services[1].id)
        assert.equals(2, res_services[2].id)
      end)
    end)

    -- When only some of the services have an OIDC configuration.
    -- This is a regression test. APIcast crashed when loading a config where only
    -- some of the services used OIDC.
    -- The reason is that we created an array of OIDC configs with
    -- size=number_of_services. Let's say we have 100 services and only the 50th has an
    -- OIDC config. In this case, we created this Lua table:
    -- { [50] = oidc_config_here }.
    -- The problem is that cjson raises an error when trying to convert a sparse array
    -- like that into JSON. Using the default cjson configuration, the minimum number
    -- of elements to reproduce the error is 11. So in this test, we create 11 services
    -- and assign an OIDC config only to the last one. Check
    -- https://www.kyne.com.au/~mark/software/lua-cjson-manual.html#encode_sparse_array
    -- for more details.
    -- Now we assign to _false_ the elements of the array that do not have an OIDC
    -- config, so this test should not crash.
    it('only some services have oidc config', function()
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
      respond_with{ status = 200, body = cjson.encode({ services = {
        { service = { id = 1 }}, { service = { id = 2 }}, { service = { id = 3 }},
        { service = { id = 4 }}, { service = { id = 5 }}, { service = { id = 6 }},
        { service = { id = 7 }}, { service = { id = 8 }}, { service = { id = 9 }},
        { service = { id = 10 }}, { service = { id = 11 }}
      }})}

      local response_body = cjson.encode(
        {
          proxy_config = { version = 13, environment = 'staging',
            content = { id = 1, backend_version = 1, proxy = { hosts = {"one.com", "first.dev"} } }
          }
        })
      test_backend.expect{ url = 'http://example.com/admin/api/services/1/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/2/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/3/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/4/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/5/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/6/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/7/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/8/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/9/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }
      test_backend.expect{ url = 'http://example.com/admin/api/services/10/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = response_body }

      test_backend.expect{ url = 'http://example.com/admin/api/services/11/proxy/configs/staging/latest.json' }.
          respond_with{ status = 200, body = cjson.encode(
            {
              proxy_config = {
                content = {
                  proxy = {
                    authentication_method= 'oidc',
                    oidc_issuer_endpoint = 'http://user:pass@idp.example.com/auth/realms/foo/'
                  }
                }
              }
            }
          )}

      test_backend.expect{ url = "http://idp.example.com/auth/realms/foo/.well-known/openid-configuration" }.
      respond_with{
        status = 200,
        headers = { content_type = 'application/json' },
        body = [[
            {
              "issuer": "https://idp.example.com/auth/realms/foo",
              "jwks_uri": "https://idp.example.com/auth/realms/foo/jwks",
              "id_token_signing_alg_values_supported": [ "RS256" ]
            }
          ]]
      }

      test_backend.expect{ url = "https://idp.example.com/auth/realms/foo/jwks" }.
      respond_with{
        status = 200,
        headers = { content_type = 'application/json' },
        body =  [[
            { "keys": [{
                "kid": "3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y",
                "kty": "RSA",
                "n": "iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw",
                "e": "AQAB"
            }] }
        ]]
      }

      local config = assert(loader:index_per_service())

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(11, #result_config.services)
      assert.equals(11, #result_config.oidc)
      assert.same({
          id_token_signing_alg_values_supported = { 'RS256' },
          issuer = 'https://idp.example.com/auth/realms/foo',
          jwks_uri = 'https://idp.example.com/auth/realms/foo/jwks'
      }, result_config.oidc[11].config)
      assert.same('https://idp.example.com/auth/realms/foo', result_config.oidc[11].issuer)
      assert.same({ ['3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y'] = {
        e = 'AQAB',
        kid = '3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y',
        kty = 'RSA',
        n = 'iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw',
        pem = [[
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiqXwBiZgN2q1dCKU1P/v
zyiGacdQhfqgxQST7GFlWU/PUljV9uHrLOadWadpxRAuskNpXWsrKoU/hDxtSpUI
RJj6hL5YTlrvv+IbFwPNtD8LnOfKL043/ZdSOe3aT4R4NrBxUomndILUESlhqddy
lVMCGXQ81OB73muc9ovR68Ajzn8KzpU/qegh8iHwk+SQvJxIIvgNJCJTC6BWnwS9
Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG+fqUAPHy5IYQaD8k8QX
0obxJ0fld61fH+Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf+KrSagD5G
UwIDAQAB
-----END PUBLIC KEY-----
]], }
      }, result_config.oidc[11].keys)
    end)
  end)

  describe(':oidc_issuer_configuration', function()
    it('does not crash on empty issuer', function()
      local service = { oidc = { issuer_endpoint = '' }}

      assert.falsy(loader.oidc:call(service.oidc.issuer_endpoint, 0))
    end)
  end)

  describe(':index_custom_path', function()
    before_each(function()
      env.set('THREESCALE_DEPLOYMENT_ENV', 'production')
    end)

    it('returns configuration for all services', function()
      loader = _M.new('http://example.com/something/with/path', { client = test_backend })
      test_backend.expect{ url = 'http://example.com/something/with/path/production.json' }.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'staging',
              content = { id = 2, backend_version = 2 }
            }
          }
        }})}

      local config = assert(loader:index_custom_path())

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
    end)

    it('returns configuration for all services with host', function()
      loader = _M.new('http://example.com/something/with/path', { client = test_backend })
      test_backend.expect{ url = 'http://example.com/something/with/path/production.json?host=foobar.example.com' }.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'production',
              content = { id = 2, backend_version = 2 }
            }
          }
        }})}

      local config = assert(loader:index_custom_path('foobar.example.com'))

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
    end)

    it('returns nil and an error if the config is not a valid', function()
      loader = _M.new('http://example.com/something/with/path', { client = test_backend })
      test_backend.expect{ url = 'http://example.com/something/with/path/production.json?host=foobar.example.com' }.
      respond_with{ status = 200, body = '{ invalid json }'}

      local config, err = loader:index_custom_path('foobar.example.com')

      assert.is_nil(config)
      assert.equals('Expected object key string but found invalid token at character 3', err)
    end)

    it('returns configuration with oidc config complete', function()
      loader = _M.new('http://example.com/something/with/path/', { client = test_backend })
      test_backend.expect{ url = 'http://example.com/something/with/path/production.json?host=foobar.example.com' }.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'staging',
              content = {
                id = 2,
                backend_version = 1,
                proxy = {
                  authentication_method= 'oidc',
                  oidc_issuer_endpoint = 'http://user:pass@idp.example.com/auth/realms/foo/'
                }
              }
            }
          }
        }})}

      test_backend.expect{ url = "http://idp.example.com/auth/realms/foo/.well-known/openid-configuration" }.
      respond_with{
        status = 200,
        headers = { content_type = 'application/json' },
        body = [[
            {
              "issuer": "https://idp.example.com/auth/realms/foo",
              "jwks_uri": "https://idp.example.com/auth/realms/foo/jwks",
              "id_token_signing_alg_values_supported": [ "RS256" ]
            }
          ]]
      }

      test_backend.expect{ url = "https://idp.example.com/auth/realms/foo/jwks" }.
      respond_with{
        status = 200,
        headers = { content_type = 'application/json' },
        body =  [[
            { "keys": [{
                "kid": "3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y",
                "kty": "RSA",
                "n": "iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw",
                "e": "AQAB"
            }] }
        ]]
      }

      local config = assert(loader:index_custom_path('foobar.example.com'))

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
      assert.same({
          id_token_signing_alg_values_supported = { 'RS256' },
          issuer = 'https://idp.example.com/auth/realms/foo',
          jwks_uri = 'https://idp.example.com/auth/realms/foo/jwks'
      }, result_config.oidc[1].config)
      assert.same('https://idp.example.com/auth/realms/foo', result_config.oidc[1].issuer)
      assert.same({ ['3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y'] = {
        e = 'AQAB',
        kid = '3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y',
        kty = 'RSA',
        n = 'iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw',
        pem = [[
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiqXwBiZgN2q1dCKU1P/v
zyiGacdQhfqgxQST7GFlWU/PUljV9uHrLOadWadpxRAuskNpXWsrKoU/hDxtSpUI
RJj6hL5YTlrvv+IbFwPNtD8LnOfKL043/ZdSOe3aT4R4NrBxUomndILUESlhqddy
lVMCGXQ81OB73muc9ovR68Ajzn8KzpU/qegh8iHwk+SQvJxIIvgNJCJTC6BWnwS9
Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG+fqUAPHy5IYQaD8k8QX
0obxJ0fld61fH+Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf+KrSagD5G
UwIDAQAB
-----END PUBLIC KEY-----
]], }
      }, result_config.oidc[1].keys)
    end)

    it('returns configuration from master endpoint', function()
      loader = _M.new('http://example.com/some/path', { client = test_backend })
      test_backend.expect{ url = 'http://example.com/some/path/production.json?host=foobar.example.com' }.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'production',
              content = { id = 2, backend_version = 2 }
            }
          }
        }})}

      local config = assert(loader:index_custom_path('foobar.example.com'))

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
    end)
  end)

  describe(':index', function()
    before_each(function()
      env.set('THREESCALE_DEPLOYMENT_ENV', 'production')
    end)

    it('invalid status is handled', function()
      test_backend.expect{ url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
      ngx.encode_args({ page = 1, per_page = 500, version = "latest" })}.
        respond_with{ status = 512, body = nil}
      assert.same({ nil, 'invalid status' }, { loader:index() })
    end)

    it('invalid status is handled when any page returns invalid status', function()
      local PROXY_CONFIGS_PER_PAGE = 500
      local page1 = proxy_config_generator(PROXY_CONFIGS_PER_PAGE)

      test_backend.expect{
        url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
        ngx.encode_args({ version = 'latest', per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode(page1) }

      test_backend.expect{ url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
      ngx.encode_args({ page = 2, per_page = 500, version = "latest" })}.
        respond_with{ status = 404, body = nil}

      assert.same({ nil, 'invalid status' }, { loader:index() })
    end)

    it('returns configuration for all proxy configs with no host', function()
      test_backend.expect{ url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
      ngx.encode_args({ version = "latest", page = 1, per_page = 500 })}.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'production',
              content = { id = 2, backend_version = 2 }
            }
          }
        }})}

      local config = assert(loader:index())

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
    end)

    it('returns configuration for all services with host', function()
      test_backend.expect{ url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
      ngx.encode_args({ host = "foobar.example.com", version = "latest", page = 1, per_page = 500 })}.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'staging',
              content = { id = 2, backend_version = 2 }
            }
          }
        }})}

      local config = assert(loader:index('foobar.example.com'))

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
    end)

    it('returns nil and an error if the config is not a valid', function()
      test_backend.expect{ url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
      ngx.encode_args({ host = "foobar.example.com", version = "latest", page = 1, per_page = 500 })}.
      respond_with{ status = 200, body = '{ invalid json }'}

      local config, err = loader:index('foobar.example.com')

      assert.is_nil(config)
      assert.equals('Expected object key string but found invalid token at character 3', err)
    end)

    it('returns configuration with oidc config complete', function()
      test_backend.expect{ url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
      ngx.encode_args({ host = "foobar.example.com", version = "latest", page = 1, per_page = 500 })}.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'staging',
              content = {
                id = 2,
                backend_version = 1,
                proxy = {
                  authentication_method= 'oidc',
                  oidc_issuer_endpoint = 'http://user:pass@idp.example.com/auth/realms/foo/'
                }
              }
            }
          }
        }})}

      test_backend.expect{ url = "http://idp.example.com/auth/realms/foo/.well-known/openid-configuration" }.
      respond_with{
        status = 200,
        headers = { content_type = 'application/json' },
        body = [[
            {
              "issuer": "https://idp.example.com/auth/realms/foo",
              "jwks_uri": "https://idp.example.com/auth/realms/foo/jwks",
              "id_token_signing_alg_values_supported": [ "RS256" ]
            }
          ]]
      }

      test_backend.expect{ url = "https://idp.example.com/auth/realms/foo/jwks" }.
      respond_with{
        status = 200,
        headers = { content_type = 'application/json' },
        body =  [[
            { "keys": [{
                "kid": "3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y",
                "kty": "RSA",
                "n": "iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw",
                "e": "AQAB"
            }] }
        ]]
      }

      local config = assert(loader:index('foobar.example.com'))

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
      assert.same({
          id_token_signing_alg_values_supported = { 'RS256' },
          issuer = 'https://idp.example.com/auth/realms/foo',
          jwks_uri = 'https://idp.example.com/auth/realms/foo/jwks'
      }, result_config.oidc[1].config)
      assert.same('https://idp.example.com/auth/realms/foo', result_config.oidc[1].issuer)
      assert.same({ ['3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y'] = {
        e = 'AQAB',
        kid = '3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y',
        kty = 'RSA',
        n = 'iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw',
        pem = [[
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiqXwBiZgN2q1dCKU1P/v
zyiGacdQhfqgxQST7GFlWU/PUljV9uHrLOadWadpxRAuskNpXWsrKoU/hDxtSpUI
RJj6hL5YTlrvv+IbFwPNtD8LnOfKL043/ZdSOe3aT4R4NrBxUomndILUESlhqddy
lVMCGXQ81OB73muc9ovR68Ajzn8KzpU/qegh8iHwk+SQvJxIIvgNJCJTC6BWnwS9
Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG+fqUAPHy5IYQaD8k8QX
0obxJ0fld61fH+Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf+KrSagD5G
UwIDAQAB
-----END PUBLIC KEY-----
]], }
      }, result_config.oidc[1].keys)
    end)

    it('returns configuration from admin portal endpoint', function()
      test_backend.expect{
        url = 'http://example.com/admin/api/account/proxy_configs/production.json?' ..
        ngx.encode_args({ host = "foobar.example.com", version = "latest", page = 1, per_page = 500 })
      }.respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'staging',
              content = { id = 2, backend_version = 2 }
            }
          }
        }})}
      local config = assert(loader:index('foobar.example.com'))

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
    end)

    it('retuns configurations from multiple pages', function()
      -- Will serve: 3 pages
      -- page 1 => PROXY_CONFIGS_PER_PAGE
      -- page 2 => PROXY_CONFIGS_PER_PAGE
      -- page 3 => 51
      local PROXY_CONFIGS_PER_PAGE = 500
      local page1 = proxy_config_generator(PROXY_CONFIGS_PER_PAGE)
      local page2 = proxy_config_generator(PROXY_CONFIGS_PER_PAGE)
      local page3 = proxy_config_generator(51)

      test_backend.expect{
        url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
        ngx.encode_args({ version = 'latest', per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode(page1) }

      test_backend.expect{
        url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
        ngx.encode_args({ version = 'latest', per_page = 500, page = 2 })}.
        respond_with{ status = 200, body = cjson.encode(page2) }

      test_backend.expect{
        url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
      ngx.encode_args({ version = 'latest', per_page = 500, page = 3 })}.
        respond_with{ status = 200, body = cjson.encode(page3) }

      local config = loader:index()

      assert.truthy(config)
      assert.equals('string', type(config))

      local result_config = cjson.decode(config)
      assert.equals(2*PROXY_CONFIGS_PER_PAGE + 51, #result_config.services)
    end)
  end)

  describe(':call', function()
    before_each(function()
      env.set('THREESCALE_DEPLOYMENT_ENV', 'production')
    end)

    it('with path on endpoint service version cannot be set', function()
      loader = _M.new('http://example.com/something/with/path', { client = test_backend })
      env.set('APICAST_SERVICE_42_CONFIGURATION_VERSION', '2')

      local config, err = loader:call()

      assert.falsy(config)
      assert.equal('APICAST_SERVICE_%s_CONFIGURATION_VERSION cannot be used when proxy config path is provided', tostring(err))
    end)

    it('with service version call index per service', function()
      env.set('APICAST_SERVICE_42_CONFIGURATION_VERSION', '2')
      test_backend.expect{ url = 'http://example.com/admin/api/services.json?'..
      ngx.encode_args({ per_page = 500, page = 1 })}.
        respond_with{ status = 200, body = cjson.encode({ services = {
            { service = { id = 42 }}
          }})
        }
      test_backend.expect{ url = 'http://example.com/admin/api/services/42/proxy/configs/production/2.json' }.
      respond_with{ status = 200, body = cjson.encode(
        {
          proxy_config = {
            version = 2,
            environment = 'production',
            content = { id = 42, backend_version = 1 }
          }
        }
      ) }

      local config = assert(loader:call())
      assert.truthy(config)
      assert.equals('string', type(config))
      assert.equals(1, #(cjson.decode(config).services))
    end)

    it('with custom path call index_custom_path', function()
      loader = _M.new('http://example.com/some/path', { client = test_backend })
      test_backend.expect{ url = 'http://example.com/some/path/production.json?host=foobar.example.com' }.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'production',
              content = { id = 2, backend_version = 2 }
            }
          }
        }})}

      local config = assert(loader:call('foobar.example.com'))

      assert.truthy(config)
      assert.equals('string', type(config))

      result_config = cjson.decode(config)
      assert.equals(1, #result_config.services)
      assert.equals(1, #result_config.oidc)
      assert.same('2', result_config.oidc[1].service_id)
    end)

    it('by default call index', function()
      test_backend.expect{ url = 'http://example.com/admin/api/account/proxy_configs/production.json?'..
      ngx.encode_args({ host = "foobar.example.com", version = "latest", page = 1, per_page = 500 })}.
        respond_with{ status = 200, body = cjson.encode({ proxy_configs = {
          {
            proxy_config = {
              version = 42,
              environment = 'production',
              content = { id = 2, backend_version = 2 }
            }
          }
        }})}

      local config = assert(loader:call("foobar.example.com"))
      assert.truthy(config)
      assert.equals('string', type(config))
      assert.equals(1, #(cjson.decode(config).services))
    end)
  end)
end)
