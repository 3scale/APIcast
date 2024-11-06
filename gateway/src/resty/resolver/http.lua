local resty_http = require 'resty.http'
local resty_resolver = require 'resty.resolver'
local round_robin = require 'resty.balancer.round_robin'

local setmetatable = setmetatable

local _M = setmetatable({}, { __index = resty_http })

local mt = { __index = _M }

function _M.new()
  local http = resty_http:new()

  http.resolver = resty_resolver:instance()
  http.balancer = round_robin.new()

  return setmetatable(http, mt)
end

function _M:resolve(host, port, options)
  local resolver = self.resolver
  local balancer = self.balancer

  if not resolver or not balancer then
    return nil, 'not initialized'
  end

  local servers = resolver:get_servers(host, options or { port = port })
  local peers = balancer:peers(servers)
  local peer = balancer:select_peer(peers)

  local ip = host

  if peer then
    ip, port = peer[1], peer[2]
  end

  return ip, port
end

function _M.connect(self, host, port, ...)
  local ip, real_port = self:resolve(host, port)
  local ok, err = resty_http.connect(self, ip, real_port, ...)

  if ok then
    self.host = host
    self.port = real_port
  end

  ngx.log(ngx.DEBUG, 'connected to  ip:', ip, ' host: ', host, ' port: ', real_port, ' ok: ', ok, ' err: ', err)

  return ok, err
end

return _M
