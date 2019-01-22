local ipairs = ipairs
local setmetatable = setmetatable

local Upstream = require('apicast.upstream')

local _M = {}

local mt = { __index = _M }

function _M.new()
  local self = setmetatable({}, mt)
  return self
end

--- Selects an upstream based on a list of rules.
-- @tparam rules table Table with instances of Rule
-- @tparam context table Context used to evaluate the conditions
-- @treturn Upstream Returns an instance of Upstream initialized with the url
--   of the first rule whose condition evaluates to true. If there are no rules
--   or none of them evaluate to true, this method returns nil.
function _M.select(_, rules, context)
  if not rules then return nil end

  for _, rule in ipairs(rules) do
    local cond_is_true = rule.condition:evaluate(context)

    if cond_is_true then
      local upstream = Upstream.new(rule.url)

      if rule.host_header and rule.host_header ~= '' then
        upstream:use_host_header(rule.host_header)
      end

      return upstream
    end
  end

  return nil
end

return _M
