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
        it('connects to the #http_proxy', function()
            _M:reset({ http_proxy = 'http://127.0.0.1:1984' })

            local request = { url = 'http://upstream:8091/request', method = 'GET' }
            local proxy = assert(_M.new(request))

            local res = assert(proxy:request(request))

            assert.same(200, res.status)
            assert.match('GET http://upstream:8091/request HTTP/1.1', res:read_body())
        end)
    end)
end)
