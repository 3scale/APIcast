local authorization = require 'resty.http_authorization'

describe('HTTP Authorization', function()

  describe('.new', function()
    it('works with empty values', function()
      local auth = authorization.new()

      assert.same(nil, auth.scheme)
      assert.same(nil, auth.param)
    end)

    it('parses scheme', function()
      local auth = authorization.new('Basic foobar')

      assert.equal('Basic', auth.scheme)
      assert.same({'userid', 'password'}, auth.credentials)
    end)

    it('parses param', function()
      local auth = authorization.new('Bearer foobar')

      assert.equal('foobar', auth.param)
      assert.same({'token'}, auth.credentials)
    end)

    it('works with unknown scheme', function()
      local auth = authorization.new('Whatever')

      assert.equal('Whatever', auth.scheme)
      assert.equal('', auth.param)
      assert.same({}, auth.credentials)
    end)
  end)

  describe('.parser', function()
    describe('Basic', function()
      it('extracts userid', function()
        local auth = authorization.new('Basic dXNlcjpwYXNz') -- user:pass

        assert.equal('user', auth.userid)
      end)

      it('extracts password', function()
        local auth = authorization.new('Basic dXNlcjpwYXNz') -- user:pass

        assert.equal('pass', auth.password)
      end)

      it('extracts empty password', function()
        local auth = authorization.new('Basic dXNlcjo=') -- user:

        assert.equal('', auth.password)
        assert.equal('user', auth.userid)
      end)

      it('extracts empty userid', function()
        local auth = authorization.new('Basic OnBhc3M=') -- :pass

        assert.equal('', auth.userid)
        assert.equal('pass', auth.password)
      end)

      it('do not panic with invalid header', function()
        local auth = authorization.new('Basic !123!')

        assert.equal(nil, auth.userid)
        assert.equal(nil, auth.password)
      end)
    end)

    describe('Bearer', function()
      it('extracts token', function()
        local auth = authorization.new('Bearer dXNlcjpwYXNz')

        assert.equal('dXNlcjpwYXNz', auth.token)
      end)
    end)
  end)

end)
