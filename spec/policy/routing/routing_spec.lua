local RoutingPolicy = require('apicast.policy.routing')
local UpstreamSelector = require('apicast.policy.routing.upstream_selector')
local Request = require('apicast.policy.routing.request')
local Upstream = require('apicast.upstream')
local mapping_rules_matcher = require('apicast.mapping_rules_matcher')

describe('Routing policy', function()
  describe('.access', function()
    it('assigns route_upstream_usage_cleanup to the context', function()
      local routing = RoutingPolicy.new()
      local context = {}
      routing:access(context)

      assert.is_function(context.route_upstream_usage_cleanup)
    end)

    it('assigns the same function reference on every call', function()
      local routing = RoutingPolicy.new()
      local ctx1 = {}
      local ctx2 = {}
      routing:access(ctx1)
      routing:access(ctx2)

      assert.equals(ctx1.route_upstream_usage_cleanup, ctx2.route_upstream_usage_cleanup)
    end)
  end)

  describe('route_upstream_usage_cleanup', function()
    it('is a no-op when route_upstream is nil', function()
      local routing = RoutingPolicy.new()
      local context = {}
      routing:access(context)

      assert.has_no_errors(function()
        context:route_upstream_usage_cleanup({}, {})
      end)
    end)

    it('calls clean_usage_by_owner_id and merges usage when route_upstream exists', function()
      local routing = RoutingPolicy.new()
      local context = {}
      routing:access(context)

      local mock_owner_id = 42
      context.route_upstream = {
        has_owner_id = function() return mock_owner_id end,
      }

      local usage_diff = { some_metric = 1 }
      stub(mapping_rules_matcher, 'clean_usage_by_owner_id').returns(usage_diff)

      local usage = { merge = function() end }
      stub(usage, 'merge')

      local matched_rules = { 'rule1', 'rule2' }

      context:route_upstream_usage_cleanup(usage, matched_rules)

      assert.stub(mapping_rules_matcher.clean_usage_by_owner_id).was_called_with(
        matched_rules, mock_owner_id
      )
      assert.stub(usage.merge).was_called_with(usage, usage_diff)
    end)
  end)

  describe('.content', function()
    describe('when there is an upstream that matches', function()
      local upstream_that_matches = Upstream.new('http://localhost')
      stub(upstream_that_matches, 'call')

      local upstream_selector = UpstreamSelector.new()
      stub(upstream_selector, 'select').returns(upstream_that_matches)

      local request = Request.new()
      local context = { request = request }

      it('calls call() on the upstream passing the context as param', function()
        local routing = RoutingPolicy.new()

        routing.upstream_selector = upstream_selector
        routing:access(context)
        routing:content(context)

        assert.stub(upstream_selector.select).was_called_with(
          upstream_selector, routing.rules, {request=request}
        )

        assert.stub(upstream_that_matches.call).was_called_with(
          upstream_that_matches, context
        )
      end)
    end)

    describe('when there is not an upstream that matches', function()
      local upstream_selector = UpstreamSelector.new()
      stub(upstream_selector, 'select').returns(nil)

      local request = Request.new()
      local context = { request = request }

      it('returns nil and the msg "no upstream"', function()
        local routing = RoutingPolicy.new()
        routing.upstream_selector = upstream_selector
        routing:access(context)
        local res, err = routing:content(context)

        assert.is_nil(res)
        assert.equals('no upstream', err)
      end)
    end)
  end)
end)
