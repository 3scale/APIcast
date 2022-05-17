local backend = require 'resty.http_ng.backend.resty'
local cjson = require 'cjson'
local http_proxy = require 'resty.http.proxy'

describe('resty backend', function()
  before_each(function()
    http_proxy:reset()
  end)

  describe('GET method #network', function()
    local method = 'GET'

    it('accesses the url', function()
      local response, err = backend:send{method = method, url = 'http://httpbin.org/get'}
      assert.falsy(err)
      assert.falsy(response.error)
      assert.truthy(response.ok)
      assert.truthy(response.request)
    end)

    it('works with ssl', function()
      local response, err = backend:send{
        method = method, url = 'https://echo-api.3scale.net/',
        -- This is needed because of https://groups.google.com/forum/#!topic/openresty-en/SuqORBK9ys0
        -- So far OpenResty can't use system certificated on demand.
        options = { ssl = { verify = false } }
      }
      assert.falsy(err)
      assert.falsy(response.error)
      assert.truthy(response.ok)
      assert.truthy(response.request)

      assert.contains({ headers = { HTTP_X_FORWARDED_PROTO = 'https' }}, cjson.decode(response.body))
    end)

    it('returns error', function()
      local req = { method = method, url = 'http://0.0.0.0:0/' }
      local response, err = backend:send(req)

      assert.falsy(err)
      assert.truthy(response.error)
      assert.falsy(response.ok)
      assert.same(req, response.request)
    end)

    context('http proxy is set', function()
      before_each(function()
        http_proxy:reset({ http_proxy = 'http://127.0.0.1:1984' })
      end)

      it('sends request through proxy', function()
        local res = assert(backend:send{method = method, url = 'http://127.0.0.1:1984/test' })

        assert.same(200, res.status)
        assert.match('GET http://127.0.0.1:1984/test HTTP/1.1', res.body)
      end)
    end)
  end)
end)
