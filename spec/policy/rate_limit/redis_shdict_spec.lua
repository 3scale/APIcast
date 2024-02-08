local env = require('resty.env')
local ts = require ('apicast.threescale_utils')

local redis_host = env.get('TEST_NGINX_REDIS_HOST') or '127.0.0.1'
local redis_port = env.get('TEST_NGINX_REDIS_PORT') or 6379
local redis_master = env.get('TEST_NGINX_REDIS_MASTER')
local redis_sentinel1_host = env.get('TEST_NGINX_REDIS_SENTINEL_1_HOST')
local redis_sentinel2_host = env.get('TEST_NGINX_REDIS_SENTINEL_2_HOST')
local redis_sentinel3_host = env.get('TEST_NGINX_REDIS_SENTINEL_3_HOST')
local redis_sentinel_port = env.get('TEST_NGINX_REDIS_SENTINEL_PORT')

local redis_shdict = require('apicast.policy.rate_limit.redis_shdict')

describe('Redis Shared Dictionary', function()
    local redis
    local shdict

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
        pending('without default', function()
            local ret, err = shdict:incr('somekey', 2)

            -- TODO: nginx shdict:incr returns: nil, 'not found' when the key does not exist
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

describe('Redis Shared Dictionary with redis Sentinel', function()
    local redis_sentinel
    local shdict

    before_each(function()
        local options = {
            url="sentinel://"..redis_master..":a/2",
            sentinels={
                {url="redis://"..redis_sentinel1_host..":"..redis_sentinel_port},
                {url="redis://"..redis_sentinel2_host..":"..redis_sentinel_port},
                {url="redis://"..redis_sentinel3_host..":"..redis_sentinel_port},
            }
        }
        redis_sentinel = assert(ts.connect_redis(options))
        shdict = assert(redis_shdict.new(options))

        assert(redis_sentinel:flushdb())
    end)

    describe('flush_all', function()
        it('removes all records', function()
            assert(redis_sentinel:set('foo', 'bar'))
            assert.equal('bar', redis_sentinel:get('foo'))

            shdict:flush_all()

            assert.equal(ngx.null, redis_sentinel:get('foo'))
        end)
    end)

    describe('incr', function()
        pending('without default', function()
            local ret, err = shdict:incr('somekey', 2)

            -- TODO: nginx shdict:incr returns: nil, 'not found' when the key does not exist
            assert.is_nil(ret)
            assert.equal('not found', err)
        end)

        it('has init value', function()
            local ret = shdict:incr('somekey', 2, 3)

            assert.equal(5, ret)
            assert.equal('5', redis_sentinel:get('somekey'))
        end)

        it('has init_ttl value', function()
            shdict:incr('somekey', 0, 0, 1)

            assert.near(1, redis_sentinel:ttl('somekey'), 0.1)
        end)

        it('increments existing value', function()
            redis_sentinel:set('somekey', 3)

            local ret = assert(shdict:incr('somekey', 2))

            assert.equal(5, ret)
        end)
    end)

    describe('get', function()
        it('returns existing existing integer', function()
            redis_sentinel:set('somekey', 1)

            local ret = shdict:get('somekey')

            assert.equal(1, ret)
        end)

        it('returns existing existing string', function()
            redis_sentinel:set('somekey', 'str')

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
            redis_sentinel:set('somekey', 'str')

            assert(shdict:set('somekey', 'somevalue'))

            assert.equal('somevalue', redis_sentinel:get('somekey'))
        end)

        it('sets value when missing', function()
            assert(shdict:set('somekey', 'foo'))

            assert.equal('foo', redis_sentinel:get('somekey'))
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

            assert.near(1, redis_sentinel:ttl('somekey'), 0.1)
        end)
    end)
end)
