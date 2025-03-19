------------
--- HTTP
-- HTTP client
-- @module http_ng.backend

local backend = {}
local response = require 'resty.http_ng.response'
local http_proxy = require 'resty.http.proxy'

local function send(httpc, params)
  params.path = params.path or params.uri.path

  local res, err = httpc:request(params)
  if not res then return nil, err end

  res.body, err = res:read_body()

  if not res.body then
    return nil, err
  end

  local ok

  ok, err = httpc:set_keepalive()

  if not ok then
    ngx.log(ngx.WARN, 'failed to set keepalive connection: ', err)
  end

  return res
end
--- Send request and return the response
-- @tparam http_ng.request request
-- @treturn http_ng.response
backend.send = function(_, request)
  local res
  local httpc, err = http_proxy.new(request)

  if err then
    return response.error(request, err)
  end

  if httpc then
    res, err = send(httpc, request)
  end

  if res then
    return response.new(request, res.status, res.headers, res.body)
  else
    return response.error(request, err)
  end
end


return backend
