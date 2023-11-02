local _M = require 'apicast.policy.apicast'

describe('APIcast policy', function()
  local ngx_on_abort_stub

  before_each(function()
      -- .access calls ngx.on_abort
      -- busted tests are called in the context of ngx.timer
      -- and that API ngx.on_abort is disabled in that context.
      -- this stub is mocking the call
      -- to prevent the internal error: API disabled in the context of ngx.timer
      ngx_on_abort_stub = stub(ngx, 'on_abort')
  end)

  it('has a name', function()
    assert.truthy(_M._NAME)
  end)

  it('has a version', function()
    assert.truthy(_M._VERSION)
  end)

  describe('.access', function()
    it('stores in the context a flag that indicates that post_action should be run', function()
      local context = {}
      local apicast = _M.new()

      apicast:access(context)

      assert.is_true(context[apicast].run_post_action)
    end)
  end)

  describe('.post_action', function()
    describe('when the "run_post_action" flag is set to true', function()
      it('runs its logic', function()
        -- A way to know whether the logic of the method run consists of
        -- checking if post_action() was called on the proxy of the context.

        local apicast = _M.new()
        local context = {
          proxy = { post_action = function() end },
          [apicast] = { run_post_action = true }
        }

        stub(context.proxy, 'post_action')

        apicast:post_action(context)

        assert.spy(context.proxy.post_action).was_called()
      end)
    end)

    describe('when the "run_post_action" flag is not set', function()
      it('does not run its logic', function()
        local apicast = _M.new()
        local context = {
          proxy = { post_action = function() end },
          [apicast] = { run_post_action = nil }
        }

        stub(context.proxy, 'post_action')

        apicast:post_action(context)

        assert.spy(context.proxy.post_action).was_not_called()
      end)
    end)
  end)
end)
