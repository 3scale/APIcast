local TransactionIDPolicy = require('apicast.policy.transaction_id')
local uuid = require('resty.jit-uuid')

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
    end)

  describe('.new', function()
    it('works without configuration', function()
      assert(TransactionIDPolicy.new())
    end)
  end)

  describe('.rewrite', function()
    it('do not overwrite existing header', function()
        ngx_req_headers['transaction-id'] = 'abc'
        local config = {header_name='transaction-id'}
        local transaction_id_policy = TransactionIDPolicy.new(config)
        transaction_id_policy:rewrite()
        assert.same('abc', ngx.req.get_headers()['transaction-id'])
    end)

    it('generate uuid if header does not exist', function()
        local config = {header_name='transaction-id'}
        local transaction_id_policy = TransactionIDPolicy.new(config)
        transaction_id_policy:rewrite()
        assert.is_true(uuid.is_valid(ngx.req.get_headers()['transaction-id']))
    end)

    it('generate uuid if header is empty', function()
        ngx_req_headers['transaction-id'] = ''
        local config = {header_name='transaction-id'}
        local transaction_id_policy = TransactionIDPolicy.new(config)
        transaction_id_policy:rewrite()
        assert.is_true(uuid.is_valid(ngx.req.get_headers()['transaction-id']))
    end)
  end)

  describe('.header_filter', function()
    it('set response transaction-id if configured', function()
        ngx_req_headers['transaction-id'] = 'abc'
        local config = {header_name='transaction-id', include_in_response=true}
        local transaction_id_policy = TransactionIDPolicy.new(config)
        transaction_id_policy:rewrite(context)
        transaction_id_policy:header_filter(context)
        assert.same('abc', ngx.header['transaction-id'])
    end)

    it('set response transaction-id if configured - uuid', function()
        ngx_req_headers['transaction-id'] = ''
        local config = {header_name='transaction-id', include_in_response=true}
        local transaction_id_policy = TransactionIDPolicy.new(config)
        transaction_id_policy:rewrite(context)
        local id = ngx.req.get_headers()['transaction-id']
        transaction_id_policy:header_filter(context)
        assert.same(id, ngx.header['transaction-id'])
    end)

    it('do not override if response contain the exisitng header', function()
        ngx_req_headers['transaction-id'] = 'abc'
        ngx_resp_headers['transaction-id'] = 'edf'
        local config = {header_name='transaction-id', include_in_response=true}
        local transaction_id_policy = TransactionIDPolicy.new(config)
        transaction_id_policy:rewrite(context)
        transaction_id_policy:header_filter(context)
        assert.same('edf', ngx.header['transaction-id'])
    end)
  end)
end)
