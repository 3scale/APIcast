local FAPIPolicy = require('apicast.policy.fapi')
local uuid = require('resty.jit-uuid')
local X509 = require('resty.openssl.x509')
local b64 = require('ngx.base64')
local clientCert = assert(fixture('CA', 'client.crt'))

local header_parameter = 'x5t#S256'

local function jwt_cnf()
  local cnf = b64.encode_base64url(X509.new(clientCert):digest('SHA256'))
  return { [header_parameter] = b64.encode_base64url(X509.new(clientCert):digest('SHA256')) }
end

describe('fapi_1_baseline_profile policy', function()
    local ngx_req_headers = {}
    local ngx_resp_headers = {}
    local context = {}
    before_each(function()
        ngx.header = {}
        ngx_req_headers = {}
        ngx_resp_headers = {}
        context = {}
        stub(ngx.req, 'get_headers', function() return ngx_req_headers end)
        stub(ngx.req, 'set_header', function(name, value) ngx_req_headers[name] = value end)
        stub(ngx.resp, 'get_headers', function() return ngx_resp_headers end)
        stub(ngx.resp, 'set_header', function(name, value) ngx_resp_headers[name] = value end)
        stub(ngx, 'print')
        stub(ngx, 'exit')
    end)

  describe('.new', function()
    it('works without configuration', function()
      assert(FAPIPolicy.new({}))
    end)
  end)

  describe('.header_filter', function()
    it('Use value from request', function()
        ngx_req_headers['x-fapi-transaction-id'] = 'abc'
        local fapi_policy = FAPIPolicy.new({})
        fapi_policy:header_filter()
        assert.same('abc', ngx.header['x-fapi-transaction-id'])
    end)

    it('Only use x-fapi-transaction-id from request if the header also exist in response from upstream', function()
        ngx_req_headers['x-fapi-transaction-id'] = 'abc'
        ngx_resp_headers['x-fapi-transaction-id'] = 'bdf'
        local fapi_policy = FAPIPolicy.new({})
        fapi_policy:header_filter()
        assert.same('abc', ngx.header['x-fapi-transaction-id'])
    end)

    it('Use x-fapi-transaction-id from upstream response', function()
        ngx_resp_headers['x-fapi-transaction-id'] = 'abc'
        local fapi_policy = FAPIPolicy.new({})
        fapi_policy:header_filter()
        assert.same('abc', ngx.header['x-fapi-transaction-id'])
    end)

    it('generate uuid if header does not exist in both request and response', function()
        local fapi_policy = FAPIPolicy.new({})
        fapi_policy:header_filter()
        assert.is_true(uuid.is_valid(ngx.header['x-fapi-transaction-id']))
    end)
  end)

  describe('x-fapi-customer-ip-address', function()
    it('Allow request with valid IPv4', function()
        ngx_req_headers['x-fapi-customer-ip-address'] = '127.0.0.1'
        local fapi_policy = FAPIPolicy.new({validate_x_fapi_customer_ip_address=true})
        fapi_policy:access()
        assert.stub(ngx.exit).was_not.called_with(403)
    end)

    it('Allow request with valid IPv6', function()
        ngx_req_headers['x-fapi-customer-ip-address'] = '2001:db8::123:12:1'
        local fapi_policy = FAPIPolicy.new({validate_x_fapi_customer_ip_address=true})
        fapi_policy:access()
        assert.stub(ngx.exit).was_not.called_with(403)
    end)

    it('Reject request if header contains more than 1 IP', function()
        ngx_req_headers['x-fapi-customer-ip-address'] = {"2001:db8::123:12:1", "127.0.0.1"}
        local fapi_policy = FAPIPolicy.new({validate_x_fapi_customer_ip_address=true})
        fapi_policy:access()
        assert.same(ngx.status, 403)
        assert.stub(ngx.print).was.called_with('{"error": "invalid_request"}')
        assert.stub(ngx.exit).was.called_with(403)
    end)
  end)
end)

describe('fapi_1 advance profile', function()
  local context = {}
  local ngx_req_headers = {}
  before_each(function()
    context = {
      jwt = {},
      service = {
        id = 4,
        auth_failed_status = 403,
        error_auth_failed = 'auth failed',
        auth_failed_headers = 'text/plain; charset=utf-8'
      }
    }

    ngx.header = {}
    ngx_req_headers = {}
    stub(ngx.req, 'get_headers', function() return ngx_req_headers end)
    stub(ngx, 'print')
    stub(ngx, 'exit')
    context.jwt = {}
  end)

  it('accepts when the digest equals cnf claim', function()
      ngx.var = { ssl_client_raw_cert = clientCert }
      context.jwt.cnf = jwt_cnf()

      local fapi_policy = FAPIPolicy.new({validate_oauth2_certificate_bound_access_token=true})
      fapi_policy:access(context)
      assert.stub(ngx.exit).was_not.called_with(403)
  end)

  it('rejects when the client certificate not found', function()
    ngx.var = { ssl_client_raw_cert = nil }
    context.jwt.cnf = jwt_cnf()

    local fapi_policy = FAPIPolicy.new({validate_oauth2_certificate_bound_access_token=true})
    fapi_policy:access(context)

    assert.stub(ngx.exit).was_called_with(ngx.HTTP_UNAUTHORIZED)
    assert.stub(ngx.print).was_called_with('{"error": "invalid_token"}')
  end)

  it('rejects when the cnf claim not defined', function()
    ngx.var = { ssl_client_raw_cert = clientCert }

    local fapi_policy = FAPIPolicy.new({validate_oauth2_certificate_bound_access_token=true})
    fapi_policy:access(context)

    assert.stub(ngx.exit).was_called_with(ngx.HTTP_UNAUTHORIZED)
    assert.stub(ngx.print).was_called_with('{"error": "invalid_token"}')
  end)

  it('rejects when context.service is nil', function()
    ngx.var = { ssl_client_raw_cert = clientCert }

    local fapi_policy = FAPIPolicy.new({validate_oauth2_certificate_bound_access_token=true})
    context.service = nil
    fapi_policy:access(context)

    assert.stub(ngx.exit).was_called_with(ngx.HTTP_UNAUTHORIZED)
    assert.stub(ngx.print).was_called_with('{"error": "invalid_token"}')
  end)

  it('rejects when the digest not equals cnf claim', function()
    ngx.var = { ssl_client_raw_cert = clientCert }

    context.jwt.cnf = {}
    context.jwt.cnf[header_parameter] = 'invalid_digest'

    local fapi_policy = FAPIPolicy.new({validate_oauth2_certificate_bound_access_token=true})
    context.service = nil
    fapi_policy:access(context)

    assert.stub(ngx.exit).was_called_with(ngx.HTTP_UNAUTHORIZED)
    assert.stub(ngx.print).was_called_with('{"error": "invalid_token"}')
  end)
end)
