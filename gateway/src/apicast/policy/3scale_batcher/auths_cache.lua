local keys_helper = require('apicast.policy.3scale_batcher.keys_helper')

local str_find = string.find
local str_sub = string.sub

local setmetatable = setmetatable
local format = string.format
local tonumber = tonumber

local _M = {}

local mt = { __index = _M }

--- Initialize a cache for authorizations.
-- @tparam storage ngx.shared.dict Shared dict to store the authorizations
-- @tparam ttl integer TTL for the cached authorizations
-- @treturn AuthsCache New cache for authorizations
function _M.new(storage, ttl)
  local self = setmetatable({}, mt)
  self.storage = storage
  self.ttl = ttl
  return self
end

local function value_to_cache(auth_status, rejection_reason)
  if rejection_reason then
    return format("%s:%s", auth_status, rejection_reason)
  else
    return auth_status
  end
end

--- Get a cached authorization.
-- @tparam transaction Transaction A transaction
-- @treturn table The table has a "status" and a "rejection_reason"
function _M:get(transaction)
  local key = keys_helper.key_for_cached_auth(transaction)
  local cached_value = self.storage:get(key)

  if not cached_value then return nil end

  local colon = str_find(cached_value, ':', 1, true)
  if colon then
    return tonumber(str_sub(cached_value, 1, colon - 1)),
      str_sub(cached_value, colon + 1)
  end

  return tonumber(cached_value)
end

--- Store an authorization in the cache.
-- @tparam transaction Transaction A transaction
-- @tparam auth_status integer Status returned by backend (200, 409, etc.)
-- @tparam[opt] rejection_reason string Rejection reason given by backend
--   when it denies an authorization
function _M:set(transaction, auth_status, rejection_reason)
  local key = keys_helper.key_for_cached_auth(transaction)
  local val_to_cache = value_to_cache(auth_status, rejection_reason)

  local ok, err = self.storage:set(key, val_to_cache, self.ttl)
  if not ok then
    ngx.log(ngx.ERR, 'Failed to set value in storage: ', err)
  end
end

return _M
