local _M = require('apicast.policy.tls_validation')

local server = assert(fixture('CA', 'server.crt'))
local CA = assert(fixture('CA', 'intermediate-ca.crt'))
local client = assert(fixture('CA', 'client.crt'))
local revoked_client = assert(fixture('CA', 'revoked_client.crt'))
local ssl_helper = require 'ssl_helper'
local crl = assert(fixture('CA', 'crl.pem'))

describe('tls_validation policy', function()
  describe('.new', function()
    it('works without configuration', function()
      assert(_M.new())
    end)

    it('accepts configuration', function()
      assert(_M.new({
        whitelist = {
          { pem_certificate = [[--BEGIN CERTIFICATE--]] }
        }
      }))
    end)
  end)

  describe(':access', function()
    before_each(function()
      stub(ngx, 'say')
      stub(ngx, 'exit')
    end)

    it('rejects non whitelisted certificate', function()
      ngx.var = { ssl_client_raw_cert = client }

      local policy = _M.new({ whitelist = { { pem_certificate = server }}})

      policy:access()

      assert.stub(ngx.exit).was_called_with(400)
      assert.stub(ngx.say).was_called_with([[TLS certificate validation failed]])
    end)

    it('rejects certificates that are not valid yet', function()
      local policy = _M.new({ whitelist = { { pem_certificate = client }}})
      ssl_helper.set_time(policy.x509_store.ctx, os.time{ year = 2000, month = 01, day = 01 })
      ngx.var = { ssl_client_raw_cert = client }

      policy:access()

      assert.stub(ngx.exit).was_called_with(400)
      assert.stub(ngx.say).was_called_with([[TLS certificate validation failed]])
    end)

    it('rejects certificates that are not longer valid', function()
      local policy = _M.new({ whitelist = { { pem_certificate = client }}})
      ssl_helper.set_time(policy.x509_store.ctx, os.time{ year = 2042, month = 01, day = 01 })
      ngx.var = { ssl_client_raw_cert = client }

      policy:access()

      assert.stub(ngx.exit).was_called_with(400)
      assert.stub(ngx.say).was_called_with([[TLS certificate validation failed]])
    end)

    it('accepts whitelisted certificate', function()
      ngx.var = { ssl_client_raw_cert = client }

      local policy = _M.new({ whitelist = { { pem_certificate = client }}})

      assert.is_true(policy:access())
    end)

    it('accepts whitelisted CA', function()
      ngx.var = { ssl_client_raw_cert = client }

      local policy = _M.new({ whitelist = { { pem_certificate = CA }}})

      assert.is_true(policy:access())
    end)

    it('accepts CRL', function()
      ngx.var = { ssl_client_raw_cert = client }

      local policy = _M.new({
        whitelist = { { pem_certificate = CA }},
        revocation_check_type = "crl",
        revoke_list = { { pem_certificate = crl }}})

      assert.is_true(policy:access())
    end)

    it('reject revoked certificate', function()
      ngx.var = { ssl_client_raw_cert = revoked_client }

      local policy = _M.new({
        whitelist = { { pem_certificate = CA }},
        revocation_check_type = "crl",
        revoke_list = { { pem_certificate = crl }}})

      policy:access()
      assert.stub(ngx.exit).was_called_with(400)
      assert.stub(ngx.say).was_called_with([[TLS certificate validation failed]])
    end)
  end)
end)
