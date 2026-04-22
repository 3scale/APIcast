
describe('http_proxy', function()
  describe('.request', function()
    local function stub_ngx_request()
      ngx.var = { }

      stub(ngx, 'exit')
      stub(ngx.req, 'get_headers', function() return { } end)
      stub(ngx.req, 'get_method', function() return 'GET' end)
    end

    local function stub_resty_http_proxy()
      local httpc = {
      }

      local response = {}
      stub(httpc, 'request', function() return response end)
      stub(httpc, 'proxy_response')
      stub(httpc, 'set_keepalive')

      local resty_http_proxy = require 'resty.http.proxy'
      stub(resty_http_proxy, 'new', function() return httpc end)
      local http_writer = require 'resty.http.response_writer'
      stub(http_writer, 'proxy_response')
    end

    before_each(function()
      stub_ngx_request()
      stub_resty_http_proxy()
    end)

    describe('on https backend', function()
      local upstream = {
        uri = {
          scheme = 'https'
        },
        request_unbuffered = false,
        skip_https_connect = false
      }
      local proxy_uri = {
      }

      before_each(function()
        stub(upstream, 'rewrite_request')
      end)

      it('terminates phase', function()
        local http_proxy = require('apicast.http_proxy')
        http_proxy.request(upstream, proxy_uri)
        assert.spy(ngx.exit).was_called_with(ngx.OK)
      end)
    end)
  end)
end)
