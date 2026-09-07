local UpstreamConnectionPolicy = require('apicast.policy.upstream_connection')

describe('Upstream connection policy', function()
  describe('.export', function()
    it('returns the timeouts included in the config', function()
      local config_timeouts = {
        connect_timeout = 1,
        send_timeout = 2,
        read_timeout = 3
      }
      local context = {}
      local policy = UpstreamConnectionPolicy.new(config_timeouts)
      policy:rewrite(context)

      assert.same(config_timeouts, context.upstream_connection_opts)
    end)

    it('does not return timeout params that is not in the config', function()
      local config_timeouts = { connect_timeout = 1 } -- Missing send and read
      local context = {}
      local policy = UpstreamConnectionPolicy.new(config_timeouts)
      policy:rewrite(context)

      assert.same(config_timeouts, context.upstream_connection_opts)
    end)

    it('reuses the same table across requests instead of allocating a new one', function()
      local policy = UpstreamConnectionPolicy.new({ connect_timeout = 1, send_timeout = 2, read_timeout = 3 })

      local context_a = {}
      local context_b = {}
      policy:rewrite(context_a)
      policy:rewrite(context_b)

      assert.equal(context_a.upstream_connection_opts, context_b.upstream_connection_opts)
    end)
  end)
end)
