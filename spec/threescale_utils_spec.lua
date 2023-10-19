local _M = require('apicast.threescale_utils')
local env = require('resty.env')

local redis_host = env.get('TEST_NGINX_REDIS_HOST') or '127.0.0.1'
local redis_port = env.get('TEST_NGINX_REDIS_PORT') or 6379
local redis_url = 'redis://'..redis_host..':'..redis_port..'/1'
local redis_master = env.get('TEST_NGINX_REDIS_MASTER')
local redis_sentinel1_host = env.get('TEST_NGINX_REDIS_SENTINEL_1_HOST')
local redis_sentinel2_host = env.get('TEST_NGINX_REDIS_SENTINEL_2_HOST')
local redis_sentinel3_host = env.get('TEST_NGINX_REDIS_SENTINEL_3_HOST')
local redis_sentinel_port = env.get('TEST_NGINX_REDIS_SENTINEL_PORT')

describe('3scale utils', function()
    describe('.error', function()
        it('returns concatenated error in timer phase', function()
            local get_phase = spy.on(ngx, 'get_phase', function() return 'timer' end)
            local error = _M.error('one', ' two', ' three')

            assert.spy(get_phase).was_called(1)

            assert.equal('one two three', error)
        end)
    end)

    describe('using #redis', function()
        it('redis url', function()
            local redis, err = _M.connect_redis({url=redis_url})
            assert(redis)
        end)
        it('invalid redis url', function()
            assert.returns_error("failed to connect to redis on invalid.domain:6379: invalid.domain could not be resolved (3: Host not found)", _M.connect_redis({url='redis://invalid.domain:6379/1'}))
        end)
    end)

    describe('using #redis-sentinel', function()
        it('redis sentinel', function()
            local redis, err = _M.connect_redis({
                url="sentinel://"..redis_master..":a/2",
                sentinels={
                    {url="redis://"..redis_sentinel1_host..":"..redis_sentinel_port},
                    {url="redis://"..redis_sentinel2_host..":"..redis_sentinel_port},
                    {url="redis://"..redis_sentinel3_host..":"..redis_sentinel_port},
                }
            })
            assert(redis)
        end)
        it('redis sentinel with empty url', function()
            local opts = {
                url="",
                sentinels={
                    {url="redis://"..redis_sentinel1_host..":"..redis_sentinel_port},
                    {url="redis://"..redis_sentinel2_host..":"..redis_sentinel_port},
                    {url="redis://"..redis_sentinel3_host..":"..redis_sentinel_port},
                }
            }
            assert.returns_error("failed to connect to redis on 127.0.0.1:6379: invalid master name", _M.connect_redis(opts))
        end)
        it('redis sentinel with invalid url', function()
            local opts = {
                url="redis://invalid.domain:6379/1",
                sentinels={
                    {url="redis://"..redis_sentinel1_host..":"..redis_sentinel_port},
                    {url="redis://"..redis_sentinel2_host..":"..redis_sentinel_port},
                    {url="redis://"..redis_sentinel3_host..":"..redis_sentinel_port},
                }
            }
            assert.returns_error("failed to connect to redis on invalid.domain:6379: invalid master name", _M.connect_redis(opts))
        end)
        it('redis sentinel with invalid master name', function()
            local opts = {
                url="sentinel://invalid.master:a/2",
                sentinels={
                    {url="redis://"..redis_sentinel1_host..":"..redis_sentinel_port},
                    {url="redis://"..redis_sentinel2_host..":"..redis_sentinel_port},
                    {url="redis://"..redis_sentinel3_host..":"..redis_sentinel_port},
                }
            }
            assert.returns_error("failed to connect to redis on 127.0.0.1:6379: invalid master name", _M.connect_redis(opts))
        end)
        it('redis sentinel with one valid sentinel', function()
            local opts = {
                url="sentinel://"..redis_master..":a/2",
                sentinels={
                    {url="redis://invalid.sentinel-2:5000"},
                    {url="redis://"..redis_sentinel1_host..":"..redis_sentinel_port},
                    {url="redis://invalid.sentinel-3:5000"},
                }
            }
            local redis, err = _M.connect_redis(opts)
            assert(redis)
        end)
        it('redis sentinel with no valid sentinels', function()
            local opts = {
                url="sentinel://"..redis_master..":a/2",
                sentinels={
                    {url="redis://invalid.sentinel-1:5000"},
                    {url="redis://invalid.sentinel-2:5000"},
                    {url="redis://invalid.sentinel-3:5000"},
                }
            }
            assert.returns_error("failed to connect to redis on 127.0.0.1:6379: no hosts available", _M.connect_redis(opts))
        end)
        it('redis sentinel with normal redis', function()
            local opts = {
                url="sentinel://"..redis_master..":a/2",
                sentinels={
                    {url=redis_url},
                }
            }
            assert.returns_error("failed to connect to redis on 127.0.0.1:6379: ERR unknown command 'sentinel', with args beginning with: 'get-master-addr-by-name' 'redismaster' ", _M.connect_redis(opts))
        end)
    end)
end)
