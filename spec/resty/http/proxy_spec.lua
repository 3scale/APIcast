local _M = require('resty.http.proxy')
local env = require('resty.env')

describe('resty.http.proxy', function()
    before_each(function()
        _M:reset()
    end)

    context('.env', function()

        context('when no proxies are set', function()
            before_each(function()
                env.set('https_proxy', nil)
                env.set('HTTPS_PROXY', nil)
                env.set('http_proxy', nil)
                env.set('HTTP_PROXY', nil)
                env.set('all_proxy', nil)
                env.set('ALL_PROXY', nil)
                env.set('no_proxy', nil)
                env.set('NO_PROXY', nil)
            end)

            it('returns empty table', function()
                assert.same({}, _M.env())
            end)
        end)

        context('when http_proxy is set', function()
            before_each(function()
                env.set('http_proxy', 'http://localhost:8091')
            end)

            it('returns http_proxy', function()
                assert.contains({ http_proxy = 'http://localhost:8091' }, _M.env())
            end)
        end)

        context('when https_proxy is set', function()
            before_each(function()
                env.set('https_proxy', 'http://localhost:8091')
            end)

            it('returns http_proxy', function()
                assert.contains({ https_proxy = 'http://localhost:8091' }, _M.env())
            end)
        end)
    end)

    context('.new', function()
      before_each(function()
        _M:reset({ http_proxy = 'http://127.0.0.1:1984' })
      end)

      it('connects to the #http_proxy', function()
          local request = { url = 'http://upstream:8091/request', method = 'GET' }
          local proxy = assert(_M.new(request))

          local res = assert(proxy:request(request))

          assert.same(200, res.status)
          assert.match('GET http://upstream:8091/request HTTP/1.1', res:read_body())
      end)

      it('connects to the #http_proxy with timeouts', function()
          local request = {
            url = 'http://upstream:8091/request',
            method = 'GET',
            timeout = {
              connect_timeout = 1,
              send_timeout = 1,
              read_timeout = 1
            }
          }

          local proxy = assert(_M.new(request))

          local res = assert(proxy:request(request))

          assert.same(200, res.status)
          assert.match('GET http://upstream:8091/request HTTP/1.1', res:read_body())
      end)
    end)

    context('.timeout', function()
      before_each(function()
        _M:reset({ http_proxy = 'http://127.0.0.1:1984' })
      end)

      describe('timeout field names', function()
          local http, httpc_mock, set_timeouts_spy

          -- Helper function to create mock httpc with spy
          local function create_httpc_mock()
              return {
                  set_timeouts = function() end,
                  connect = function() return true end,
                  request = function() return { status = 200, read_body = function() return 'ok' end } end,
                  close = function() end,
                  set_keepalive = function() end,
                  pool = 'test',
                  get_reused_times = function() return 0 end,
                  host = 'example.com',
                  port = 443
              }
          end

          before_each(function()
              http = require('resty.resolver.http')
              httpc_mock = create_httpc_mock()
              set_timeouts_spy = spy.new(function() end)
              httpc_mock.set_timeouts = set_timeouts_spy
              stub(http, 'new', function() return httpc_mock end)
          end)

          it('should accept timeouts with connect_timeout, send_timeout, read_timeout fields', function()
              -- This test verifies the actual structure passed from http_proxy.lua
              local request = {
                  url = 'http://upstream:8091/request',
                  method = 'GET',
                  -- This mimics the actual structure from http_proxy.lua:152
                  -- timeouts = opts.upstream_connection_opts
                  timeout = {
                      connect_timeout = 1,
                      send_timeout = 2,
                      read_timeout = 3
                  }
              }

              local proxy = assert(_M.new(request))

              -- Verify set_timeouts was called with milliseconds (timeout * 1000)
              assert.spy(set_timeouts_spy).was_called()
              assert.spy(set_timeouts_spy).was_called_with(
                  match.is_table(),  -- self (httpc)
                  1000,  -- connect_timeout: 1 sec -> 1000 ms
                  2000,  -- send_timeout: 2 sec -> 2000 ms
                  3000   -- read_timeout: 3 sec -> 3000 ms
              )
          end)

          it('should handle nil timeout values', function()
              local request = {
                  url = 'http://upstream:8091/request',
                  method = 'GET',
                  timeout = {
                      connect_timeout = 1,
                      send_timeout = nil,  -- nil timeout should be handled
                      read_timeout = 3
                  }
              }

              assert(_M.new(request))

              -- Verify set_timeouts handles nil correctly
              assert.spy(set_timeouts_spy).was_called()
              assert.spy(set_timeouts_spy).was_called_with(
                  match.is_table(),
                  1000,
                  nil,   -- send_timeout is nil
                  3000
              )
          end)

          it('should skip timeout setting when timeouts is nil', function()
              local request = {
                  url = 'http://upstream:8091/request',
                  method = 'GET',
                  timeout = nil  -- No timeouts specified
              }

              assert(_M.new(request))

              -- set_timeouts should NOT be called when timeouts is nil
              assert.spy(set_timeouts_spy).was_not_called()
          end)

          it('should convert seconds to milliseconds correctly', function()
              local request = {
                  url = 'http://upstream:8091/request',
                  method = 'GET',
                  timeout = {
                      connect_timeout = 0.5,   -- 500ms
                      send_timeout = 1.5,      -- 1500ms
                      read_timeout = 10        -- 10000ms
                  }
              }

              assert(_M.new(request))

              assert.spy(set_timeouts_spy).was_called_with(
                  match.is_table(),
                  500,    -- 0.5 * 1000
                  1500,   -- 1.5 * 1000
                  10000   -- 10 * 1000
              )
          end)
      end)
    end)

    describe('options.ssl', function()
        local http, httpc_mock, connect_spy

        local function create_httpc_mock()
            return {
                set_timeouts = function() end,
                connect = function() return true end,
                request = function() return { status = 200, read_body = function() return 'ok' end } end,
                close = function() end,
                set_keepalive = function() end,
                pool = 'test',
                get_reused_times = function() return 0 end,
                host = 'example.com',
                port = 443
            }
        end

        before_each(function()
            http = require('resty.resolver.http')
            httpc_mock = create_httpc_mock()
            connect_spy = spy.new(function() return true end)
            httpc_mock.connect = connect_spy
            stub(http, 'new', function() return httpc_mock end)
        end)

        it('propagates options.ssl.verify to the connect ssl_verify option (used by http_ng)', function()
            local request = {
                url = 'https://upstream:8091/request',
                method = 'GET',
                options = { ssl = { verify = true } }
            }

            assert(_M.new(request))

            local connect_options = connect_spy.calls[1].vals[2]
            assert.is_true(connect_options.ssl_verify)
        end)

        it('propagates options.ssl.client_cert/client_priv_key set by the forward-proxy path', function()
            local cert, key = 'cert-data', 'key-data'
            local request = {
                url = 'https://upstream:8091/request',
                method = 'GET',
                options = { ssl = { verify = true, client_cert = cert, client_priv_key = key } }
            }

            assert(_M.new(request))

            local connect_options = connect_spy.calls[1].vals[2]
            assert.same(cert, connect_options.ssl_client_cert)
            assert.same(key, connect_options.ssl_client_priv_key)
        end)

        it('defaults ssl_verify to false when options.ssl is not set', function()
            local request = { url = 'https://upstream:8091/request', method = 'GET' }

            assert(_M.new(request))

            local connect_options = connect_spy.calls[1].vals[2]
            assert.is_false(connect_options.ssl_verify)
        end)
    end)
end)
