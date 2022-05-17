local _M = require('apicast.policy').new('Clear Context')
local new = _M.new

function _M.new(...)
  return new(...)
end

function _M:ssl_certificate(context)
  --resetting the context after every other policy in the chain
  --has executed their ssl_certificate phase. 
  clear_table(ngx.ctx)
end

function clear_table(t)
  for k, _ in pairs(t) do
    t[k] = nil
  end
end

return _M
