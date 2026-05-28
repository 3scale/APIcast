local camel_policy = require('apicast.policy.camel')
local resty_url = require 'resty.url'

describe('Camel policy', function()
  local all_proxy_val = "http://all.com"
  local http_proxy_val = "http://plain.com"
  local https_proxy_val = "http://secure.com"

  local http_uri = {scheme="http"}
  local https_uri = {scheme="https"}
  local context

  before_each(function()
    context = {}
  end)

  it("http[s] proxies are defined if all_proxy is in there", function()
    local proxy = camel_policy.new({
      all_proxy = all_proxy_val
    })
    proxy:rewrite(context)

    assert.same(context.get_http_proxy(http_uri), resty_url.parse(all_proxy_val))
    assert.same(context.get_http_proxy(https_uri), resty_url.parse(all_proxy_val))
  end)

  it("all_proxy does not overwrite http/https proxies", function()
    local proxy = camel_policy.new({
      all_proxy = all_proxy_val,
      http_proxy = http_proxy_val,
      https_proxy = https_proxy_val
    })
    proxy:rewrite(context)

    assert.same(context.get_http_proxy(http_uri), resty_url.parse(http_proxy_val))
    assert.same(context.get_http_proxy(https_uri), resty_url.parse(https_proxy_val))
  end)

  it("empty config return all nil", function()
    local proxy = camel_policy.new({})
    proxy:rewrite(context)

    assert.is_nil(context.get_http_proxy(https_uri))
    assert.is_nil(context.get_http_proxy(http_uri))
  end)

  describe("get_http_proxy callback", function()
    local proxy = camel_policy.new({
        all_proxy = all_proxy_val
    })

    it("Valid protocol", function()
      proxy:rewrite(context)
      local result = context.get_http_proxy(
        resty_url.parse("http://google.com"))
      assert.same(result, resty_url.parse(all_proxy_val))
    end)

    it("invalid protocol", function()
      proxy:rewrite(context)
      local result = context.get_http_proxy({scheme="invalid"})
      assert.is_nil(result)
    end)

    it("nil scheme", function()
      proxy:rewrite(context)
      local result = context.get_http_proxy({})
      assert.is_nil(result)
    end)

  end)

  describe(".access", function()
    it("sets skip_https_connect_on_proxy on context", function()
      local proxy = camel_policy.new({ all_proxy = all_proxy_val })

      local mock_upstream = { set_skip_https_connect_on_proxy = stub.new() }
      context.get_upstream = function() return mock_upstream end

      proxy:access(context)

      assert.is_true(context.skip_https_connect_on_proxy)
    end)

    it("calls set_skip_https_connect_on_proxy on upstream", function()
      local proxy = camel_policy.new({ all_proxy = all_proxy_val })

      local mock_upstream = { set_skip_https_connect_on_proxy = stub.new() }
      context.get_upstream = function() return mock_upstream end

      proxy:access(context)

      assert.stub(mock_upstream.set_skip_https_connect_on_proxy).was_called()
    end)

    it("does not error when get_upstream returns nil", function()
      local proxy = camel_policy.new({ all_proxy = all_proxy_val })

      context.get_upstream = function() return nil end

      assert.has_no.errors(function() proxy:access(context) end)
      assert.is_true(context.skip_https_connect_on_proxy)
    end)
  end)
end)
