local resty_http = require 'resty.http'
local resty_resolver = require 'resty.resolver'
local round_robin = require 'resty.balancer.round_robin'
local url_helper = require('resty.url_helper')
local format = string.format

local setmetatable = setmetatable
local resty_env = require 'resty.env'
local tonumber = tonumber
local keepalive_request = resty_env.get('APICAST_LUA_SOCKET_KEEPALIVE_REQUESTS')

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

function _M.connect(self, options, ...)
  -- cache the host because we need to resolve host to IP
  local host = options.host
  local proxy_opts = options.proxy_opts
  local proxy = proxy_opts and (proxy_opts.http_proxy or proxy_opts.https_proxy)
  local ip, real_port

  -- target server requires hostname not IP and DNS resolution is left to the proxy itself as specified in the RFC #7231
  -- https://httpwg.org/specs/rfc7231.html#CONNECT
  --
  -- Therefore, only resolve host IP when not using with proxy
  if not proxy then
    ip, real_port = self:resolve(options.host, options.port)
    options.host = ip
    options.port = real_port
  else
    local proxy_uri, err = url_helper.parse_url(proxy)
    if not proxy_uri then
      return nil, 'invalid proxy: ' .. err
    end

    -- Resolve the proxy IP/Port
    local proxy_host, proxy_port = self:resolve(proxy_uri.host, proxy_uri.port)
    local proxy_url = format("%s://%s:%s", proxy_uri.scheme, proxy_host, proxy_port)

    if proxy_opts.http_proxy then
      options.proxy_opts.http_proxy =  proxy_url
    elseif proxy_opts.https_proxy then
      options.proxy_opts.https_proxy =  proxy_url
    end
  end

  local ok, err = resty_http.connect(self, options, ...)

  if ok then
    -- use correct host header
    self.host = host
    self.port = options.port
  end

  ngx.log(ngx.DEBUG, 'connected to  ip:', ip, ' host: ', host, ' port: ', real_port, ' ok: ', ok, ' err: ', err)

  return ok, err
end

function _M:set_keepalive()
  if keepalive_request then
    local count, err = resty_http.get_reused_times(self)
    if err then
      return nil, err
    end
    if count >= tonumber(keepalive_request) then
      resty_http.close(self)
      return true
    end
  end

  local ok, err = resty_http.set_keepalive(self)
  if not ok then
    return nil, err
  end
  return true
end

return _M
