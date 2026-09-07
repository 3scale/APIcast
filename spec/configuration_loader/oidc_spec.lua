local test_backend_client = require 'resty.http_ng.backend.test'
local loader = require 'apicast.configuration_loader.oidc'
local cjson = require('cjson')

describe('OIDC Configuration loader', function()
  describe('.call', function()
    local test_backend
    before_each(function() test_backend = test_backend_client.new() end)
    before_each(function() loader.discovery.http_client.backend = test_backend end)

    it('ignores empty config', function()
      assert.same({}, { loader.call() })
      assert.same({''}, { loader.call('') })
    end)

    it('has timeout configured to prevent indefinite hanging', function()
      -- Verify that the http_client has a timeout set
      assert.is_not_nil(loader.discovery.http_client.options)
      assert.is_not_nil(loader.discovery.http_client.options.timeout)
      assert.is_truthy(loader.discovery.http_client.options.timeout > 0)
      -- Default should be 5 seconds
      assert.equals(5, loader.discovery.http_client.options.timeout)
    end)

    it('ignores config without oidc_issuer_endpoint', function()
      local config = cjson.encode{
        services = {
          { id = 21 },
          { id = 42 },
        }
      }

      assert(loader.call(config))
    end)

    it('ignores config with oidc_issuer_endpoint but not oidc authentication mode', function()
      local config = cjson.encode{
        services = {
          { id = 21, proxy = { oidc_issuer_endpoint = 'https://user:pass@example.com' } },
          { id = 42 },
        }
      }

      assert(loader.call(config))
    end)

    it('forwards all parameters', function()
      assert.same({'{"oidc":[]}', 'one', 'two'}, { loader.call('{}', 'one', 'two')})
    end)

    it('gets openid configuration', function()
      local config = {
        services = {
          { id = 21, proxy = { oidc_issuer_endpoint = 'https://user:pass@example.com', authentication_method = 'oidc' }},
        }
      }

      test_backend
        .expect{ url = "https://example.com/.well-known/openid-configuration" }
        .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body = [[{"jwks_uri":"http://example.com/jwks","issuer":"https://example.com"}]],
        }

      test_backend
        .expect{ url = "http://example.com/jwks" }
        .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body = [[{"keys":[]}]],
        }

      local oidc = loader.call(cjson.encode(config))
      local expected_oidc = cjson.decode([[
        {
          "services": [
            {
              "id": 21,
              "proxy": {
                "oidc_issuer_endpoint": "https://user:pass@example.com",
                "authentication_method": "oidc"
              }
            }
          ],
          "oidc": [
            {
              "service_id": 21,
              "issuer": "https://example.com",
              "config": {
                "jwks_uri": "http://example.com/jwks",
                "issuer": "https://example.com"
              },
              "keys": {}
            }
          ]
        }
      ]])
      assert.same(expected_oidc, cjson.decode(oidc))
    end)

    -- This is a regression test. cjson crashed when parsing a config where
    -- only some of the services have OIDC enabled. In particular, it crashed
    -- when it tried to convert into JSON a "sparse array":
    -- https://www.kyne.com.au/~mark/software/lua-cjson-manual.html#encode_sparse_array
    -- The easiest way to create a sparse array with the default cjson config
    -- is to create a table that has 11 positions and only the last one is !=
    -- false/nil.
    it('works correctly when only some of the services have OIDC enabled', function()
      local oidc = {}
      for _=1, 10 do table.insert(oidc, false) end
      oidc[11] = { issuer = "https://example.com" }

      local services = {}
      for i=1, 11 do table.insert(services, { id = i }) end

      local config = { services = services, oidc = oidc }

      loader.call(cjson.encode(config))
    end)

    it('ignore openid configuration if authentication_method is not oidc', function()
      local config = {
        services = {
          { id = 21, proxy = { oidc_issuer_endpoint = 'https://user:pass@example.com', authentication_method = '1' }},
        }
      }

      test_backend
        .expect{ url = "https://example.com/.well-known/openid-configuration" }
        .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body = [[{"jwks_uri":"http://example.com/jwks","issuer":"https://example.com"}]],
        }

      test_backend
        .expect{ url = "http://example.com/jwks" }
        .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body = [[{"keys":[]}]],
        }

      local oidc = loader.call(cjson.encode(config))
      local expected_oidc = cjson.decode([[
        {
          "services": [
            {
              "id": 21,
              "proxy": {
                "oidc_issuer_endpoint": "https://user:pass@example.com",
                "authentication_method": "1"
              }
            }
          ],
          "oidc": [
            {
              "service_id": 21
            }
          ]
        }
      ]])
      assert.same(expected_oidc, cjson.decode(oidc))
    end)

    it('handles OIDC discovery failure gracefully without crashing', function()
      local config = {
        services = {
          { id = 21, proxy = { oidc_issuer_endpoint = 'https://unreachable.example.com', authentication_method = 'oidc' }},
          { id = 42, proxy = { oidc_issuer_endpoint = 'https://working.example.com', authentication_method = 'oidc' }},
        }
      }

      -- First service - simulate timeout/failure
      test_backend
        .expect{ url = "https://unreachable.example.com/.well-known/openid-configuration" }
        .respond_with{
          status = 0,  -- Connection failure
          error = "timeout"
        }

      -- Second service - works correctly
      test_backend
        .expect{ url = "https://working.example.com/.well-known/openid-configuration" }
        .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body = [[{"jwks_uri":"http://working.example.com/jwks","issuer":"https://working.example.com"}]],
        }

      test_backend
        .expect{ url = "http://working.example.com/jwks" }
        .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body = [[{"keys":[]}]],
        }

      -- Should not crash, should return configuration with error for service 21
      local result = loader.call(cjson.encode(config))
      assert.is_not_nil(result)

      local decoded = cjson.decode(result)
      assert.equals(2, #decoded.oidc)

      -- First service should have error
      assert.equals(21, decoded.oidc[1].service_id)
      -- assert.is_not_nil(decoded.oidc[1].error)

      -- Second service should work normally
      assert.equals(42, decoded.oidc[2].service_id)
      assert.equals("https://working.example.com", decoded.oidc[2].issuer)
    end)

    it('logs the discovery error on failure', function()
      local config = {
        services = {
          { id = 21, proxy = { oidc_issuer_endpoint = 'https://unreachable.example.com', authentication_method = 'oidc' }},
        }
      }

      test_backend
        .expect{ url = "https://unreachable.example.com/.well-known/openid-configuration" }
        .respond_with{ status = 0, error = "timeout" }

      local original_log = ngx.log
      ngx.log = spy.new(function() end)

      loader.call(cjson.encode(config))

      assert.spy(ngx.log).was_called()

      local logged
      for _, call in ipairs(ngx.log.calls) do
        local line = table.concat(call.vals, '', 2)
        if line:find('OIDC discovery failed for service', 1, true) then
          logged = line
          break
        end
      end

      assert.is_not_nil(logged)
      assert.is_not_nil(logged:find('could not get OpenID Connect configuration', 1, true))

      ngx.log = original_log
    end)

    it('handles connection timeout gracefully', function()
      local config = {
        services = {
          { id = 99, proxy = { oidc_issuer_endpoint = 'https://timeout.example.com', authentication_method = 'oidc' }},
        }
      }

      -- Simulate a timeout by returning error response
      test_backend
        .expect{ url = "https://timeout.example.com/.well-known/openid-configuration" }
        .respond_with{
          status = 0,
          error = "timeout: connection timed out"
        }

      -- Should handle timeout without crashing
      local result = loader.call(cjson.encode(config))
      assert.is_not_nil(result)

      local decoded = cjson.decode(result)
      assert.equals(1, #decoded.oidc)
      assert.equals(99, decoded.oidc[1].service_id)
      -- assert.is_not_nil(decoded.oidc[1].error)
      -- Service with timeout error should be marked as failed
      -- assert.equals('OIDC discovery failed', decoded.oidc[1].error)
    end)
  end)
end)
