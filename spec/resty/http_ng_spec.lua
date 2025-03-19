local http_ng = require 'resty.http_ng'
local fake_backend = require 'fake_backend_helper'
local resty_backend = require 'resty.http_ng.backend.resty'

describe('http_ng', function()
  local http, backend
  before_each(function()
    backend = fake_backend.new()
    http = http_ng.new{ backend = backend }
  end)

  for _,method in ipairs{ 'get', 'head', 'options', 'delete' } do
    it('makes ' .. method .. ' call to backend', function()
      local response = http[method]('http://example.com')
      local last_request = assert(backend.last_request)

      assert.truthy(response)
      assert.equal(method:upper(), last_request.method)
      assert.equal('http://example.com', last_request.url)
      assert.equal(last_request, response.request)
    end)
  end

  it('OPTIONS method works with default options', function()
    http = http_ng.new{backend = backend, options = { headers = { host = "foo" }}}
    local response = http.OPTIONS('http://example.com')
    local last_request = assert(backend.last_request)

    assert.truthy(response)
    assert.equal('OPTIONS', last_request.method)
    assert.equal('http://example.com', last_request.url)
    assert.equal('foo', last_request.headers.host)
  end)

  pending('options method works with default options', function()
    http = http_ng.new{backend = backend, options = { headers = { host = "foo" }}}
    local response = http.options('http://example.com')
    local last_request = assert(backend.last_request)

    assert.truthy(response)
    assert.equal('OPTIONS', last_request.method)
    assert.equal('http://example.com', last_request.url)
    assert.equal('foo', last_request.headers.host)
  end)

  for _,method in ipairs{ 'put', 'post', 'patch' } do
    it('makes ' .. method .. ' call to backend with body', function()
      local response = http[method]('http://example.com', 'body')
      local last_request = assert(backend.last_request)

      assert.truthy(response)
      assert.equal(method:upper(), last_request.method)
      assert.equal('http://example.com', last_request.url)
      assert.equal('body', last_request.body)
    end)
  end

  describe('x-www-form-urlencoded', function()
    local body = { value = 'some' }

    it('serializes table as form-urlencoded', function()
      http.post('http://example.com', body)

      local last_request = assert(backend.last_request)
      assert.equal('application/x-www-form-urlencoded', last_request.headers.content_type)
      assert.equal('value=some', last_request.body)
    end)
  end)

  describe('array syntax', function()
    it('works for get', function()
      http.get{'http://example.com', headers = { custom = 'value'} }
      local last_request = assert(backend.last_request)
      assert.equal('value', last_request.headers.custom)
    end)

    it('works for post', function()
      http.post{'http://example.com', 'body', headers = { custom = 'value'} }
      local last_request = assert(backend.last_request)
      assert.equal('value', last_request.headers.Custom)
      assert.equal('body', last_request.body)
    end)
  end)

  describe('inital options', function()
    it('can turn off ssl validation', function()
      http = http_ng.new{backend = backend, options = { ssl = { verify = false } } }

      http.get('http://example.com')
      local last_request = assert(backend.last_request)

      assert.equal(false, last_request.options.ssl.verify)
    end)
    it('can turn off ssl validation for methods with body', function()
      http = http_ng.new{backend = backend, options = { ssl = { verify = false } } }

      http.post('http://example.com', {})
      local last_request = assert(backend.last_request)

      assert.equal(false, last_request.options.ssl.verify)
    end)
  end)

  describe('headers', function()
    local headers = { custom_header = 'value' }

    it('parses userid and password from the url', function()
      http.get('http://foo:bar@example.com')

      local last_request = assert(backend.last_request)

      assert.equal('Basic ' .. ngx.encode_base64('foo:bar'), last_request.headers.authorization)
    end)

    it('can override Host header', function()
      http.get('http://example.com', { headers = { host = 'overriden' }})
      local last_request = assert(backend.last_request)
      assert.equal('overriden', last_request.headers.host)
    end)

    it('overrides headers from initial options', function()
      http = http_ng.new{backend = backend, options = { headers = { user_agent = 'foobar' } } }

      http.get('http://example.com', { headers = { user_agent = 'overriden' }})

      local last_request = assert(backend.last_request)
      assert.equal('overriden', last_request.headers.user_agent)
    end)

    it('uses headers from initial options', function()
      http = http_ng.new{backend = backend, options = { headers = { user_agent = 'foobar' } } }

      http.get('http://example.com')

      local last_request = assert(backend.last_request)
      assert.equal('foobar', last_request.headers.user_agent)
    end)

    it('merges passed headers with initial options', function()
      http = http_ng.new{backend = backend, options = { headers = { user_agent = 'foo' } } }

      http.get('http://example.com', { headers = { host = 'bar' }})
      local last_request = assert(backend.last_request)

      assert.equal('foo', last_request.headers.user_agent)
      assert.equal('bar', last_request.headers.host)
    end)

    it('uses initial headers for all requests', function()
      http = http_ng.new{backend = backend, options = { headers = { user_agent = 'foo' } } }
      http.get('http://example.com')
      http.get('http://example.com')

      local last_request = assert(backend.last_request)

      assert.equal('foo', last_request.headers.user_agent)
    end)

    it('passed headers for requests with body', function()
      http.post('http://example.com', '', { headers = headers })
      local last_request = assert(backend.last_request)
      assert.equal('value', last_request.headers['Custom-Header'])
    end)

    it('passed headers for requests without body', function()
      http.get('http://example.com', { headers = headers })
      local last_request = assert(backend.last_request)
      assert.equal('value', last_request.headers['Custom-Header'])
    end)

    it('properly extracts header from complicated calls', function()
      http.get('http://localhost:3000/auth/realms/rh-sso-demo/protocol/openid-connect/auth?client_id=foobar&redirect_uri=http://127.0.0.1:3011&response_type=code&scope=test')

      local last_request = assert(backend.last_request)

      assert.equal('localhost:3000', last_request.headers['Host'])
    end)
  end)

  describe('json', function()
    it('has serializer', function()
      assert.equal(http_ng.serializers.json, http.json.serializer)
    end)

    it('doesnt have serializer', function()
      assert.falsy(http.unknown)
    end)

    it('serializes body as json', function()
      http.json.post('http://example.com', {table = 'value'})

      assert.equal('{"table":"value"}', backend.last_request.body)
      assert.equal(#'{"table":"value"}', backend.last_request.headers['Content-Length'])
      assert.equal('application/json', backend.last_request.headers['Content-Type'])
    end)

    it('accepts json as a string', function()
      http.json.post('http://example.com', '{"table" : "value"}')
      assert.equal('{"table" : "value"}', backend.last_request.body)
      assert.equal(#'{"table" : "value"}', backend.last_request.headers['Content-Length'])
      assert.equal('application/json', backend.last_request.headers['Content-Type'])
    end)

    it('does not override passed headers', function()
      http.json.post('http://example.com', '{}', { headers = { content_type = 'custom/format' }})
      assert.equal('custom/format', backend.last_request.headers['Content-Type'])
    end)
  end)

  describe('when there is no error', function()
    local response
    before_each(function()
      http = http_ng.new{ backend = resty_backend }
      response = http.get('http://127.0.0.1:1984')
    end)

    it('is ok', function()
      assert.equal(true, response.ok)
    end)

    it('has no error', function()
      assert.equal(nil, response.error)
    end)
  end)

  describe('when there is error #network', function()
    local response
    before_each(function()
      http = http_ng.new{ backend = resty_backend }
      response = http.get('http://127.0.0.1:1')
    end)

    it('is not ok', function()
      assert.equal(false, response.ok)
    end)

    it('has error', function()
      assert.equal("connection refused", response.error)
    end)
  end)

  describe('works with api.twitter.com #network', function()

    it('connects #twitter', function()
      local client = http_ng.new{ backend = resty_backend }
      local response = client.get('http://api.twitter.com/')
      assert(response.ok, 'response is not ok')
    end)
  end)
end)
