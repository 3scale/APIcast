
describe('http_proxy', function()
  describe('.request', function()
    local function stub_ngx_request()
      ngx.var = { }

      stub(ngx, 'exit')
      stub(ngx.req, 'get_headers', function() return { } end)
      stub(ngx.req, 'get_method', function() return 'GET' end)
    end

    local captured_request = nil

    local function stub_resty_http_proxy(response)
      local httpc = {
      }

      response = response or {}
      stub(httpc, 'request', function() return response end)
      stub(httpc, 'proxy_response')
      stub(httpc, 'set_keepalive')

      local resty_http_proxy = require 'resty.http.proxy'
      stub(resty_http_proxy, 'new', function(request)
        captured_request = request
        return httpc
      end)
      local http_writer = require 'resty.http.response_writer'
      stub(http_writer, 'proxy_response')
    end

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
        stub_ngx_request()
        stub(upstream, 'rewrite_request')
      end)

      it('terminates phase', function()
        stub_resty_http_proxy()
        local http_proxy = require('apicast.http_proxy')
        http_proxy.request(upstream, proxy_uri)
        assert.spy(ngx.exit).was_called_with(ngx.OK)
      end)

      it('handles nil upstream_connection_opts gracefully', function()
        captured_request = nil  -- Reset captured request
        stub_resty_http_proxy()

        local upstream = {
          uri = {
            scheme = 'https',
            host = 'api.example.com'
          },
          request_unbuffered = false,
          skip_https_connect = false,
          upstream_connection_opts = nil,  -- No timeouts configured
          rewrite_request = function() end
        }

        local http_proxy = require('apicast.http_proxy')
        http_proxy.request(upstream, proxy_uri)

        -- Verify resty.http.proxy.new was called with a request
        assert.is_not_nil(captured_request, 'proxy.new should have been called')

        -- timeouts should be nil when upstream_connection_opts is nil
        assert.is_nil(captured_request.timeout, 'request.timeout should be nil when not configured')
      end)

      it('passes timeouts to proxy.new at top level', function()
        captured_request = nil  -- Reset captured request
        stub_resty_http_proxy()

        local upstream = {
          uri = {
            scheme = 'https',
            host = 'api.example.com',
            path = '/v1/endpoint'
          },
          request_unbuffered = false,
          skip_https_connect = false,
          upstream_connection_opts = {
            connect_timeout = 5,
            send_timeout = 10,
            read_timeout = 30
          },
          rewrite_request = function() end
        }

        local http_proxy = require('apicast.http_proxy')
        http_proxy.request(upstream, proxy_uri)

        -- Verify resty.http.proxy.new was called
        assert.is_not_nil(captured_request, 'proxy.new should have been called')

        -- Verify that timeouts were extracted to top level
        assert.is_not_nil(captured_request.timeout, 'request.timeout should not be nil')
        assert.same({
          connect_timeout = 5,
          send_timeout = 10,
          read_timeout = 30
        }, captured_request.timeout, 'timeout should be extracted from upstream_connection_opts')

        -- Verify proxy_options still contains the original structure
        assert.is_not_nil(captured_request.proxy_options)
        assert.same(upstream.upstream_connection_opts,
                    captured_request.proxy_options.upstream_connection_opts,
                    'proxy_options should still contain upstream_connection_opts')
      end)

      it('stores upstream status and response time in ngx.ctx', function()
        stub_resty_http_proxy({ status = 200 })
        ngx.ctx = {}
        local http_proxy = require('apicast.http_proxy')
        http_proxy.request(upstream, proxy_uri)
        assert.equal(200, ngx.ctx.proxy_upstream_status)
        assert.is_number(ngx.ctx.proxy_upstream_response_time)
      end)
    end)
  end)
end)
