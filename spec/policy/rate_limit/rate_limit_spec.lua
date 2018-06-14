local RateLimitPolicy = require('apicast.policy.rate_limit')
local match = require('luassert.match')
local env = require('resty.env')

local shdict_mt = {
  __index = {
    get = function(t, k) return rawget(t, k) end,
    set = function(t, k, v) rawset(t, k , v); return true end,
    incr = function(t, key, inc, init, _)
      local value = t:get(key) or init
      if not value then return nil, 'not found' end

      t:set(key, value + inc)
      return t:get(key)
    end,
  }
}
local function shdict()
  return setmetatable({ }, shdict_mt)
end

local function is_gt(_, arguments)
  local expected = arguments[1]
  return function(value)
    return value > expected
  end
end
assert:register("matcher", "gt", is_gt)

local ts = require ('apicast.threescale_utils')

local redis_host = env.get('TEST_NGINX_REDIS_HOST') or 'localhost'
local redis_port = env.get('TEST_NGINX_REDIS_PORT') or 6379

local redis_url = 'redis://'..redis_host..':'..redis_port..'/1'
local redis = ts.connect_redis{ url = redis_url }

describe('Rate limit policy', function()
  local ngx_exit_spy
  local ngx_sleep_spy
  local context

  setup(function()
    ngx_exit_spy = spy.on(ngx, 'exit')
    ngx_sleep_spy = spy.on(ngx, 'sleep')
  end)

  before_each(function()
    redis:flushdb()
  end)

  before_each(function()
    ngx.var = {
      request_time = '0.060',
      host = 'test3',
    }

    ngx.shared.limiter = mock(shdict(), true)

    context = {
      service = {
        id = 5
      }
    }
  end)

  describe('.access', function()
    describe('using #shmem', function()
      setup(function()
        ngx.shared.limiter = shdict()
      end)

      it('works without redis', function()
        local rate_limit_policy = RateLimitPolicy.new({
          connection_limiters = {
            { key = { name = 'test1', scope = 'global' }, conn = 20, burst = 10, delay = 0.5 }
          }
        })

        assert(rate_limit_policy:access(context))
      end)

      it('works with multiple limiters', function()
        local rate_limit_policy = RateLimitPolicy.new({
          connection_limiters = {
            { key = { name = 'test1', scope = 'global' }, conn = 20, burst = 10, delay = 0.5 }
          },
          leaky_bucket_limiters = {
            { key = { name = 'test2', scope = 'global' }, rate = 18, burst = 9 }
          },
          fixed_window_limiters = {
            { key = { name = 'test3', scope = 'global' }, count = 10, window = 10 }
          },
        })

        assert(rate_limit_policy:access(context))
      end)
    end)

    describe('using #redis', function()
      it('works with multiple limiters', function()
        local rate_limit_policy = RateLimitPolicy.new({
          connection_limiters = {
            { key = { name = 'test1', scope = 'global' }, conn = 20, burst = 10, delay = 0.5 }
          },
          leaky_bucket_limiters = {
            { key = { name = 'test2', scope = 'global' }, rate = 18, burst = 9 }
          },
          fixed_window_limiters = {
            { key = { name = 'test3', scope = 'global' }, count = 10, window = 10 }
          },
          redis_url = redis_url
        })

        assert(rate_limit_policy:access(context))
      end)

      it('invalid redis url', function()
        local rate_limit_policy = RateLimitPolicy.new({
          connection_limiters = {
            { key = { name = 'test1', scope = 'global' }, conn = 20, burst = 10, delay = 0.5 }
          },
          redis_url = 'redis://invalidhost:'..redis_port..'/1'
        })

        rate_limit_policy:access(context)

        assert.spy(ngx_exit_spy).was_called_with(500)
      end)

      describe('rejection', function()
        it('rejected (conn)', function()
          local rate_limit_policy = RateLimitPolicy.new({
            connection_limiters = {
              { key = { name = 'test1', scope = 'global' }, conn = 1, burst = 0, delay = 0.5 }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(context)
          rate_limit_policy:access(context)

          assert.spy(ngx_exit_spy).was_called_with(429)
        end)

        it('rejected (req)', function()
          local rate_limit_policy = RateLimitPolicy.new({
            leaky_bucket_limiters = {
              { key = { name = 'test2', scope = 'global' }, rate = 1, burst = 0 }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(context)
          rate_limit_policy:access(context)

          assert.spy(ngx_exit_spy).was_called_with(429)
        end)

        it('rejected (count), name_type is plain', function()
          local rate_limit_policy = RateLimitPolicy.new({
            fixed_window_limiters = {
              { key = { name = 'test3', name_type = 'plain', scope = 'global' }, count = 1, window = 10 }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(context)
          rate_limit_policy:access(context)

          local redis_key = redis:keys('*_fixed_window_test3')[1]
          assert.equal('2', redis:get(redis_key))
          assert.spy(ngx_exit_spy).was_called_with(429)
        end)

        it('rejected (count), name_type is liquid', function()
          local ctx = { service = { id = 5 }, var_in_context = 'test3' }
          local rate_limit_policy = RateLimitPolicy.new({
            fixed_window_limiters = {
              { key = { name = '{{ var_in_context }}', name_type = 'liquid', scope = 'global' },
                count = 1, window = 10 }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(ctx)
          rate_limit_policy:access(ctx)

          local redis_key = redis:keys('*_fixed_window_test3')[1]
          assert.equal('2', redis:get(redis_key))
          assert.spy(ngx_exit_spy).was_called_with(429)
        end)

        it('rejected (count), name_type is liquid, ngx variable', function()
          local rate_limit_policy = RateLimitPolicy.new({
            fixed_window_limiters = {
              { key = { name = '{{ host }}', name_type = 'liquid', scope = 'global' }, count = 1, window = 10 }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(context)
          rate_limit_policy:access(context)

          local redis_key = redis:keys('*_fixed_window_test3')[1]
          assert.equal('2', redis:get(redis_key))
          assert.spy(ngx_exit_spy).was_called_with(429)
        end)
      end)

      describe('delay', function()
        it('delay (conn)', function()
          local rate_limit_policy = RateLimitPolicy.new({
            connection_limiters = {
              { key = { name = 'test1', scope = 'global' }, conn = 1, burst = 1, delay = 2 }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(context)
          rate_limit_policy:access(context)

          assert.spy(ngx_sleep_spy).was_called_with(match.is_gt(0.001))
        end)

        it('delay (req)', function()
          local rate_limit_policy = RateLimitPolicy.new({
            leaky_bucket_limiters = {
              { key = { name = 'test2', scope = 'global' }, rate = 1, burst = 1 }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(context)
          rate_limit_policy:access(context)

          assert.spy(ngx_sleep_spy).was_called_with(match.is_gt(0.001))
        end)

        it('delay (req) service scope', function()
          local rate_limit_policy = RateLimitPolicy.new({
            leaky_bucket_limiters = {
              {
                key = { name = 'test4', scope = 'service' },
                rate = 1,
                burst = 1
              }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(context)
          rate_limit_policy:access(context)

          assert.spy(ngx_sleep_spy).was_called_with(match.is_gt(0.001))
        end)

        it('delay (req) default service scope', function()
          local rate_limit_policy = RateLimitPolicy.new({
            leaky_bucket_limiters = {
              {
                key = { name = 'test4' },
                rate = 1,
                burst = 1
              }
            },
            redis_url = redis_url
          })

          rate_limit_policy:access(context)
          rate_limit_policy:access(context)

          assert.spy(ngx_sleep_spy).was_called_with(match.is_gt(0.001))
        end)
      end)
    end)

    describe('.log', function()
      it('success in leaving', function()
        local rate_limit_policy = RateLimitPolicy.new({
          connection_limiters = {
            { key = { name = 'test1', scope = 'global' }, conn = 20, burst = 10, delay = 0.5 }
          },
          redis_url = redis_url
        })

        rate_limit_policy:access(context)

        assert(rate_limit_policy:log())
      end)
    end)
  end)
end)
