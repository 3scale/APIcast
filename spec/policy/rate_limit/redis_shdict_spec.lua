local env = require('resty.env')
local ts = require ('apicast.threescale_utils')

local redis_host = env.get('TEST_NGINX_REDIS_HOST') or '127.0.0.1'
local redis_port = env.get('TEST_NGINX_REDIS_PORT') or 6379

local redis_shdict = require('apicast.policy.rate_limit.redis_shdict')

describe('Redis Shared Dictionary', function()
    local redis
    local shdict

    describe('new', function()
        it('invalid redis url', function()
            local _, err = redis_shdict.new{ host = "invalid", port = 6379 }
            assert.match("failed to connect to redis on invalid:6379", err)
        end)

        it('invalid redis auth', function()
            local _, err = redis_shdict.new{ host = redis_host, port = redis_port, db=1 , password = "invalid"}
            assert.match("failed to auth on redis ".. redis_host .. ":" .. redis_port ..", err: ERR AUTH <password> called without any password configured for the default user. Are you sure your configuration is correct?", err)
        end)

        it('invalid redis db', function()
            local _, err = redis_shdict.new{ host = redis_host, port = redis_port, db = 1000}
            assert.match("failed to select db 1000 on redis " .. redis_host ..":" .. redis_port .. ", err: ERR DB index is out of range", err)
        end)
    end)

    before_each(function()
        local options = { host = redis_host, port = redis_port, db = 1 }
        redis = assert(ts.connect_redis(options))
        shdict = assert(redis_shdict.new(options))

        assert(redis:flushdb())
    end)


    describe('flush_all', function()
        it('removes all records', function()
            assert(redis:set('foo', 'bar'))
            assert.equal('bar', redis:get('foo'))

            shdict:flush_all()

            assert.equal(ngx.null, redis:get('foo'))
        end)
    end)

    describe('incr', function()
        it('without default', function()
            local ret, err = shdict:incr('somekey', 2)

            -- nginx shdict:incr returns: nil, 'not found' when the key does not exist
            assert.is_nil(ret)
            assert.equal('not found', err)
        end)

        it('has init value', function()
            local ret = shdict:incr('somekey', 2, 3)

            assert.equal(5, ret)
            assert.equal('5', redis:get('somekey'))
        end)

        it('has init_ttl value', function()
            shdict:incr('somekey', 0, 0, 1)

            assert.near(1, redis:ttl('somekey'), 0.1)
        end)

        it('increments existing value', function()
            redis:set('somekey', 3)

            local ret = assert(shdict:incr('somekey', 2))

            assert.equal(5, ret)
        end)
    end)

    describe('get', function()
        it('returns existing existing integer', function()
            redis:set('somekey', 1)

            local ret = shdict:get('somekey')

            assert.equal(1, ret)
        end)

        it('returns existing existing string', function()
            redis:set('somekey', 'str')

            local ret = shdict:get('somekey')

            assert.equal('str', ret)
        end)

        it('returns nil on missing value', function()
            local ret = { shdict:get('missing') }

            assert.equal(0, #ret)
        end)
    end)

    describe('set', function()
        it('overrides existing value', function()
            redis:set('somekey', 'str')

            assert(shdict:set('somekey', 'somevalue'))

            assert.equal('somevalue', redis:get('somekey'))
        end)

        it('sets value when missing', function()
            assert(shdict:set('somekey', 'foo'))

            assert.equal('foo', redis:get('somekey'))
        end)
    end)

    describe('expire', function()
        it('returns an error on missing key', function()
            local ok, err = shdict:expire('somekey', 1)

            assert.is_nil(ok)
            assert.equal('not found', err)
        end)

        it('sets value when missing', function()
            shdict:set('somekey', 'value')

            assert(shdict:expire('somekey', 1))

            assert.near(1, redis:ttl('somekey'), 0.1)
        end)
    end)
end)
