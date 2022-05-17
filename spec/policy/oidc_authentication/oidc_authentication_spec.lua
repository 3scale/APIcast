local _M = require('apicast.policy.oidc_authentication')
local JWT = require('resty.jwt')
local rsa = require('fixtures.rsa')
local OIDC = require('apicast.oauth.oidc')
local http_ng = require 'resty.http_ng'

local access_token = setmetatable({
  header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
  payload = {
    iss = 'http://example.com/issuer',
    sub = 'some',
    aud = 'one',
    exp = ngx.now() + 3600,
  },
}, { __tostring = function(jwt) return JWT:sign(rsa.private, jwt) end })

describe('oidc_authentication policy', function()
  describe('.new', function()
    it('works without configuration', function()
      assert(_M.new())
    end)

    it('accepts empty configuration', function()
        assert(_M.new({ }))
    end)

    it('accepts issuer_endpoint configuration', function()
      http_ng.backend()
        .expect{ url = "http://example.com/path/.well-known/openid-configuration" }
        .respond_with{ status = 404 }

      assert(_M.new({ issuer_endpoint = 'http://example.com/path' }))
    end)

    it('ignores invalid issuer_endpoint configuration', function()
      assert(_M.new({ issuer_endpoint = 'http: example.com path' }))
    end)

    it('uses discovery', function()
      local issuer_endpoint = 'http://example.com'

      do
        local test_backend = http_ng.backend()
        local jwks_uri = issuer_endpoint .. '/jwks'

        test_backend
                .expect{ url = issuer_endpoint .. "/.well-known/openid-configuration" }
                .respond_with{ status = 200, headers = { content_type = 'application/json;charset=UTF-8' },
                               body = [[
              {
                "issuer": "]] .. issuer_endpoint .. [[",
                "jwks_uri": "]] .. jwks_uri .. [[",
                "id_token_signing_alg_values_supported": [ "RS256" ]
              }
            ]] }

        test_backend
                .expect{ url = jwks_uri }
                .respond_with{
          status = 200,
          headers = { content_type = 'application/json' },
          body =  [[ { "keys": [{
                        "kid": "3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y",
                        "kty": "RSA",
                        "n": "iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw",
                        "e": "AQAB"
                      }] } ]]
        }
      end

      _M.new{ issuer_endpoint = issuer_endpoint }
    end)
  end)

  describe(':rewrite', function()
    before_each(function()
      ngx.var = {}
    end)

    it('works without config', function()
      _M.new():rewrite({})
    end)

    it('works with empty config', function()
      _M.new({}):rewrite({})
    end)

    it('stores parsed access token in the context', function()
      local policy = _M.new()
      local context = { jwt = {} }

      ngx.var.http_authorization = 'Bearer ' .. tostring(access_token)

      policy.oidc.alg_whitelist = { RS256 = true }
      policy.oidc.keys = { [access_token.header.kid] = { pem = rsa.pub } }

      policy:rewrite(context)

      assert.is_table(context.jwt)
      assert.same(access_token.payload, context.jwt.payload)
    end)

    it('handles invalid token', function()
      local policy = _M.new()
      local context = { }

      ngx.var.http_authorization = 'Bearer ' .. 'invalid token value'

      policy:rewrite(context)

      assert.is_table(context.jwt)
      assert.contains({reason = 'invalid jwt string', valid = false }, context.jwt)
    end)
  end)

  describe(':access', function()

    it('works without config', function()
      _M.new():access({})
    end)

    it('works with empty config', function()
      _M.new({}):access({})
    end)

    context('when OIDC is required', function ()

      local policy
      before_each(function()
          policy = _M.new{ required = true }
      end)

      it('sends a challenge when token is not sent', function()
        spy.on(ngx, 'exit')

        ngx.header = { }
        policy:access({})

        assert.spy(ngx.exit).was_called_with(ngx.HTTP_UNAUTHORIZED)
        assert.same('Bearer', ngx.header.www_authenticate)
      end)

      it('returns forbidden on invalid token', function()
        spy.on(ngx, 'exit')
        local jwt = { token = 'invalid' }
        local context = { [policy] = jwt }

        ngx.header = { }
        policy:access(context)

        assert.spy(ngx.exit).was_called_with(ngx.HTTP_FORBIDDEN)
      end)

    end)

    context('when OIDC is optional', function ()
      local policy
      before_each(function()
        policy = _M.new{ required = false }
      end)

      it('does nothing when token is not sent', function()
        spy.on(ngx, 'exit')

        policy:access({})

        assert.spy(ngx.exit).was_not_called()
      end)

      it('returns forbidden on invalid token', function()
        spy.on(ngx, 'exit')
        local jwt = { token = 'invalid' }
        local context = { [policy] = jwt }

        ngx.header = { }
        policy:access(context)

        assert.spy(ngx.exit).was_called_with(ngx.HTTP_FORBIDDEN)
      end)
    end)

    it('continues on valid token', function()
      spy.on(ngx, 'exit')

      local oidc = OIDC.new{
        issuer = access_token.payload.iss,
        config = { id_token_signing_alg_values_supported = { access_token.header.alg } },
        keys = { [access_token.header.kid] = { pem = rsa.pub, alg = access_token.header.alg }  },
      }
      local policy = _M.new{ oidc = oidc }
      local jwt = oidc:parse(access_token)
      local context = { [policy] = jwt }

      assert.is_true(policy:access(context))

      assert.spy(ngx.exit).was_not_called()
    end)
  end)
end)
