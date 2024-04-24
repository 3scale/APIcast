--- Transaction ID policy
-- This policy add a uniqud ID to the user defined header. This can help to identify
-- request from access log or the trace

local policy = require('apicast.policy')
local _M = policy.new('Transaction ID', 'builtin')

local uuid = require 'resty.jit-uuid'

local new = _M.new

function _M.new(config)
  local self = new(config)
  local conf = config or {}
  self.header_name = conf.header_name
  self.include_in_response = conf.include_in_response or false

  return self
end

function _M:rewrite(context)
  local transaction_id = ngx.req.get_headers()[self.header_name]

  if not transaction_id or transaction_id == "" then
    transaction_id = uuid.generate_v4()
    ngx.req.set_header(self.header_name, transaction_id)
  end

  if self.include_in_response then
    context.transaction_id = transaction_id
  end
end

function _M:header_filter(context)
  if not self.include_in_response then
    return
  end

  local transaction_id = ngx.resp.get_headers()[self.header_name]
  if not transaction_id or transaction_id == "" then
    transaction_id = context.transaction_id
  end
  ngx.header[self.header_name] = transaction_id
end

return _M
