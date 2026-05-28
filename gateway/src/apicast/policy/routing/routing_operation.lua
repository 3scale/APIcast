--- RoutingOperation
-- This module is based on the Operation one. The only difference is that
-- operations for the routing policy check request information that is not
-- available when the operation is instantiated, like headers, query arguments,
-- etc. That is the reason why in instances of this module, there are functions
-- to get the left operand instead of the operand itself.

local setmetatable = setmetatable
local match = ngx.re.match
local TemplateString = require('apicast.template_string')

local _M = {}

local mt = { __index = _M }

local evaluate_func = {
  ['=='] = function(left, right) return tostring(left) == tostring(right) end,
  ['!='] = function(left, right) return tostring(left) ~= tostring(right) end,

  -- Implemented on top of ngx.re.match. Returns true when there is a match and
  -- false otherwise.
  ['matches'] = function(left, right)
    return (match(tostring(left), tostring(right)) and true) or false
  end
}

local function new(evaluate_left_side_func, op, value, value_type)
  local self = setmetatable({}, mt)

  self.evaluate_left_side_func = evaluate_left_side_func
  self.evaluate_func = evaluate_func[op]
  assert(self.evaluate_func, 'Unsupported operation: ' .. (op or 'nil'))
  self.right_template = TemplateString.new(value, value_type or 'plain')

  return self
end

function _M.new_op_with_path(op, value, value_type)
  local eval_left_func = function(context) return context.request:get_uri() end
  return new(eval_left_func, op, value, value_type)
end

function _M.new_op_with_header(header_name, op, value, value_type)
  local eval_left_func = function(context)
    return context.request:get_header(header_name)
  end

  return new(eval_left_func, op, value, value_type)
end

function _M.new_op_with_query_arg(query_arg_name, op, value, value_type)
  local eval_left_func = function(context)
    return context.request:get_uri_arg(query_arg_name)
  end

  return new(eval_left_func, op, value, value_type)
end

function _M.new_op_with_jwt_claim(jwt_claim_name, op, value, value_type)
  local eval_left_func = function(context)
    local jwt = context.request:get_validated_jwt()
    return (jwt and jwt[jwt_claim_name]) or nil
  end

  return new(eval_left_func, op, value, value_type)
end

function _M.new_op_with_liquid_templating(liquid_expression, op, value, value_type)
  local template = TemplateString.new(liquid_expression or "", "liquid")
  local eval_left_func = function(context)
    return template:render(context)
  end

  return new(eval_left_func, op, value, value_type)
end

function _M:evaluate(context)
  local left = self.evaluate_left_side_func(context)
  local right = self.right_template:render(context)
  return self.evaluate_func(left, right)
end

return _M
