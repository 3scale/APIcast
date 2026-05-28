local ipairs = ipairs
local format = string.format
local str_find = string.find
local insert = table.insert
local concat = table.concat
local sort = table.sort
local unpack = table.unpack
local ngx_re = ngx.re
local new_tab = require('resty.core.base').new_tab

local _M = {}

local function creds_part_in_key(creds)
  if creds.app_id and creds.app_key then
    return format("app_id:%s,app_key:%s", creds.app_id, creds.app_key)
  elseif creds.user_key then
    return format("user_key:%s", creds.user_key)
  elseif creds.access_token then
    return format("access_token:%s", creds.access_token)
  elseif creds.app_id then
    return format("app_id:%s", creds.app_id)
  end
end

local function metrics_part_in_key(usage)
  local usages = new_tab(#usage.metrics, 0)

  local deltas = usage.deltas

  -- Need to sort the metrics. Otherwise, same metrics but in different order,
  -- would end up in a different key.
  local metrics = { unpack(usage.metrics) } -- Does not modify the original.
  sort(metrics)

  for _, metric in ipairs(metrics) do
    insert(usages, format("%s=%s", metric, deltas[metric]))
  end

  return format("metrics:%s", concat(usages, ';'))
end

local regexes_report_key = {
  user_key= [[service_id:(?<service_id>[\w-]+),user_key:(?<user_key>[\S-]+),metric:(?<metric>[\S-]+)]],
  access_token = [[service_id:(?<service_id>[\w-]+),access_token:(?<access_token>[\S-]+),metric:(?<metric>[\S-]+)]],
  app_key = [[service_id:(?<service_id>[\w-]+),app_id:(?<app_id>[\S-]+),app_key:(?<app_key>[\S-]+),metric:(?<metric>[\S-]+)]],
  app_id = [[service_id:(?<service_id>[\w-]+),app_id:(?<app_id>[\S-]+),metric:(?<metric>[\S-]+)]],
}


local function detect_cred_type(key)
  if str_find(key, 'user_key:', 1, true) then
    return 'user_key'
  elseif str_find(key, 'access_token:', 1, true) then
    return 'access_token'
  elseif str_find(key, 'app_key:', 1, true) then
    return 'app_key'
  elseif str_find(key, 'app_id:', 1, true) then
    return 'app_id'
  end
end

function _M.key_for_cached_auth(transaction)
  local service_part = format("service_id:%s", transaction.service_id)
  local creds_part = creds_part_in_key(transaction.credentials)
  local metrics_part = metrics_part_in_key(transaction.usage)

  return format("%s,%s,%s", service_part, creds_part, metrics_part)
end

function _M.key_for_batched_report(service_id, credentials, metric_name)
  local creds_part = creds_part_in_key(credentials)

  return format("service_id:%s,%s,metric:%s",
                service_id, creds_part, metric_name)
end

function _M.report_from_key_batched_report(key, value)
  local cred_type = detect_cred_type(key)
  if not cred_type then
    return nil, 'credentials not found'
  end

  local match = ngx_re.match(key, regexes_report_key[cred_type], 'oj')
  if not match then
    return nil, "credentials not found"
  end

  -- some credentials will be nil.
  return {
    service_id = match.service_id,
    metric = match.metric,
    user_key = match.user_key,
    access_token = match.access_token,
    app_id = match.app_id,
    app_key = match.app_key,
    value = value
  }
end

return _M
