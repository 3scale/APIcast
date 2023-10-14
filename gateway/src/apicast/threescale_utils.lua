local sub = string.sub
local tonumber = tonumber

local redis = require 'resty.redis.connector'
local env = require 'resty.env'

local resty_resolver = require 'resty.resolver'
local resty_balancer = require 'resty.balancer'

local resty_url = require 'resty.url'

local _M = {} -- public interface

local redis_conf = {
  timeout   = 3000,  -- 3 seconds
  keepalive = 10000, -- milliseconds
  poolsize  = 1000   -- # connections
}

-- private
-- Logging Helpers
function _M.show_table(t)
  local indent = 0 --arg[1] or 0
  local indentStr=""
  local msg
  for _ = 1,indent do indentStr=indentStr.."  " end

  for k,v in pairs(t) do
    if type(v) == "table" then
      msg = indentStr .. _M.show_table(v or '', indent+1)
    else
      msg = indentStr ..  k .. " => " .. v
    end
    _M.log_message(msg)
  end
end

function _M.log_message(str)
  ngx.log(0, str)
end

function _M.newline()
  ngx.log(0,"  ---   ")
end

function _M.log(content)
  if type(content) == "table" then
    _M.log_message(_M.show_table(content))
  else
    _M.log_message(content)
  end
  _M.newline()
end

-- End Logging Helpers

-- Table Helpers
function _M.keys(t)
  local n=0
  local keyset = {}
  for k,_ in pairs(t) do
    n=n+1
    keyset[n]=k
  end
  return keyset
end
-- End Table Helpers


function _M.dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then
        k = '"'..k..'"'
      end
      s = s .. '['..k..'] = ' .. _M.dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

function _M.sha1_digest(s)
  local str = require "resty.string"
  return str.to_hex(ngx.sha1_bin(s))
end

-- returns true iif all elems of f_req are among actual's keys
function _M.required_params_present(f_req, actual)
  local req = {}
  for k,_ in pairs(actual) do
    req[k] = true
  end
  for _,v in ipairs(f_req) do
    if not req[v] then
      return false
    end
  end
  return true
end

local balancer = resty_balancer.new(function(peers) return peers[1] end)

function _M.resolve(host, port)
  local resolver = resty_resolver:instance()

  local servers = resolver:get_servers(host, { port = port })
  local peers = balancer:peers(servers)
  local peer = balancer:select_peer(peers)

  local ip = host

  if peer then
    ip = peer[1]
    port = peer[2]
  end

  return ip, port
end


function _M.connect_redis(options)
  local opts = {}

  local url = options and options.url or env.get('REDIS_URL')


  if url then
    url = resty_url.split(url, 'redis')
    if url then
      opts.host = url[4]
      opts.port = url[5]
      opts.db = url[6] and tonumber(sub(url[6], 2))
      opts.password = url[3] or url[2]
    end
  elseif options then
    opts.host = options.host
    opts.port = options.port
    opts.db = options.db
    opts.password = options.password
  end

  opts.connect_timeout = options and options.timeout or redis_conf.timeout

  local host = opts.host or env.get('REDIS_HOST') or "127.0.0.1"
  local port = opts.port or env.get('REDIS_PORT') or 6379
  host, port = _M.resolve(host, port)

  local rc = redis.new({
      connect_timeout = opts.timeout,

      host = host,
      port = port,
      db = opts.db,
      password = opts.password,
  })

  local red, err = rc:connect()
  if not red then
    return nil, _M.error("failed to connect to redis on ", host, ":", port, ": ", err)
  end

  return red
end

-- return ownership of this connection to the pool
function _M.release_redis(red)
  red:set_keepalive(redis_conf.keepalive, redis_conf.poolsize)
end

local xml_header_len = string.len('<?xml version="1.0" encoding="UTF-8"?>')

function _M.match_xml_element(xml, element, value)
  if not xml then return nil end
  local pattern = string.format('<%s>%s</%s>', element, value, element)
  return string.find(xml, pattern, xml_header_len, xml_header_len, true)
end

-- error and exit
function _M.error(...)
  if ngx.get_phase() == 'timer' then
    return table.concat(table.pack(...))
  else
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say(...)
    ngx.exit(ngx.status)
  end
end

function _M.missing_args(text)
  ngx.say(text)
  ngx.exit(ngx.HTTP_OK)
end

---
-- Builds a query string from a table.
--
-- This is the inverse of <code>parse_query</code>.
-- @param query A dictionary table where <code>table['name']</code> =
-- <code>value</code>.
-- @return A query string (like <code>"name=value2&name=value2"</code>).
-----------------------------------------------------------------------------
function _M.build_query(query)
  local qstr = ""

  for i,v in pairs(query) do
    qstr = qstr .. i .. '=' .. v .. '&'
  end
  return string.sub(qstr, 0, #qstr-1)
end

return _M

-- -- Example usage:
-- local MM = require 'mymodule'
-- MM.bar()
