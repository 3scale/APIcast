--- Policy Config Validator
-- @module policy_config_validator
-- Validates a policy configuration against a policy config JSON schema.

local jsonschema = require('jsonschema')
local lrucache = require("resty.lrucache")

local cached_validator = lrucache.new(100)

local _M = {
  _VERSION=0.1
}

local function create_validator(schema)
  local ok, res = pcall(jsonschema.generate_validator, schema)
  if ok then
    return res
  end

  return nil, res
end

local function get_validator(schema)
  local validator, err = cached_validator:get(schema)
  if not validator then
    validator, err = create_validator(schema)
    if not validator then
      return nil, err
    end
    cached_validator:set(schema, validator)
  end

  return validator, nil
end

--- Validate a policy configuration
-- Checks if a policy configuration is valid according to the given schema.
-- @tparam table config Policy configuration
-- @tparam table config_schema Policy configuration schema
-- @treturn boolean True if the policy configuration is valid. False otherwise.
-- @treturn string Error message only when the policy config is invalid.
function _M.validate_config(config, config_schema)
  local validator, err = get_validator(config_schema or {})
  if not validator then
    return false, err
  end
  return validator(config or {})
end

return _M
