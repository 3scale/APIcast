local assert = assert
local dict = 'prometheus_metrics'

if ngx.shared[dict] then
  local metrics = { }
  local prometheus = require('prometheus').init(dict)

  local __call = function(_, type, name, ...)
    local metric_name = assert(name, 'missing metric name')

    if not metrics[metric_name] then
      metrics[metric_name] = prometheus[assert(type, 'missing metric type')](prometheus, metric_name, ...)
    end

    return metrics[metric_name]
  end

  local function init_worker()
    prometheus:init_worker()
  end

  local function collect()
    prometheus:collect()
  end

  return setmetatable({
    init_worker = init_worker,
    collect = collect,
  }, { __call = __call})
else
  local noop = function() end
  local noop_metric = { inc = noop, set = noop, observe = noop, del = noop, reset = noop }
  local __call = function() return noop_metric end
  return setmetatable({ collect = noop, init_worker = noop }, { __call = __call })
end
