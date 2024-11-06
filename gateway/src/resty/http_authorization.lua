local setmetatable = setmetatable
local match = string.match

local _M = {
  _VERSION = '0.1',
  parsers = { }
}

local mt = { __index = _M }

function _M.parsers.Basic(param)
  local userid, password
  local user_pass = ngx.decode_base64(param)
  if user_pass then
    userid, password = match(user_pass, '^(.*):(.*)$')
  end

  return {
    userid = userid,
    password = password,
    credentials = { 'userid', 'password' }
  }
end

function _M.parsers.Bearer(param)
  return {
    token = param,
    credentials = { 'token' }
  }
end

function _M.parsers.null()
  return {
    credentials = { }
  }
end

function _M.new(value)
  local scheme, param = match(value or '', "^(%w+)%s*(.*)$")
  local parse = _M.parsers[scheme] or _M.parsers.null
  local parsed = setmetatable(parse(param), mt)

  return setmetatable({
    scheme = scheme,
    param = param
  }, { __index = parsed })
end

return _M
