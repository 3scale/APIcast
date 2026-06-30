
describe('prometheus', function()
  before_each(function()
    package.loaded['apicast.prometheus'] = nil
    package.loaded['prometheus'] = nil
  end)

  describe('shared dictionary is missing', function()
    before_each(function() ngx.shared.prometheus_metrics = nil end)

    it('can be called', function()
      local prom = require('apicast.prometheus')
      local metric = prom()
      assert.is_not_nil(metric)
      assert.is_function(metric.inc)
    end)

    it('can be collected', function()
      assert.is_nil(require('apicast.prometheus'):collect())
    end)
  end)

  describe('shared dictionary is there', function()
    local saved_get_phase

    before_each(function()
      ngx.shared.prometheus_metrics = {
        set = function() return true end,
        safe_set = function() return true end,
        safe_add = function() return true end,
        incr = function() return 0 end,
        get = function() end,
        delete = function() return true end,
        get_keys = function() return {} end,
      }
      saved_get_phase = ngx.get_phase
      ngx.get_phase = function() return 'init' end
    end)

    after_each(function()
      ngx.get_phase = saved_get_phase
    end)

    it('returns a callable wrapper', function()
      local prometheus = assert(require('apicast.prometheus'))
      local metric = prometheus('counter', 'test_metric', 'A test counter')
      assert.is_not_nil(metric)
    end)

    it('caches metrics by name', function()
      local prometheus = assert(require('apicast.prometheus'))
      local m1 = prometheus('counter', 'cached_metric', 'A counter')
      local m2 = prometheus('counter', 'cached_metric', 'A counter')
      assert.are.equal(m1, m2)
    end)

    it('exposes collect', function()
      local prometheus = assert(require('apicast.prometheus'))
      assert.is_function(prometheus.collect)
    end)

    it('exposes init_worker', function()
      local prometheus = assert(require('apicast.prometheus'))
      assert.is_function(prometheus.init_worker)
    end)
  end)

end)
