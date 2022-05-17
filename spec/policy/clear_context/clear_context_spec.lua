local ClearContextPolicy = require('apicast.policy.clear_context')
local ngx_variable = require('apicast.policy.ngx_variable')
   

describe('Clear Context policy', function()
  local current_ctx = {some_key = 'some_value'}

  describe('log phase context reset', function()
    before_each(function()
      ctx = ngx.ctx
      stub(ngx_variable, 'available_context', function(context) return context end)
    end)

    context('.ssl_certificate', function()
      local clear_context_policy = ClearContextPolicy.new()

      it('clears the context', function()
        ctx.current = current_ctx
        clear_context_policy:ssl_certificate(ctx)
        assert.is_nil(ctx.current)
      end)
    end)
  end)
end)


