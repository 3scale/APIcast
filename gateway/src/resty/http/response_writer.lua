local fmt = string.format
local str_lower = string.lower
local insert = table.insert
local concat = table.concat

local ngx       = ngx

local _M = {
}

local cr_lf = "\r\n"

-- http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.1
local HOP_BY_HOP_HEADERS = {
    ["connection"]          = true,
    ["keep-alive"]          = true,
    ["proxy-authenticate"]  = true,
    ["proxy-authorization"] = true,
    ["te"]                  = true,
    ["trailers"]            = true,
    ["transfer-encoding"]   = true,
    ["upgrade"]             = true,
    ["content-length"]      = true, -- Not strictly hop-by-hop, but Nginx will deal
                                    -- with this (may send chunked for example).
}

local function send(socket, data)
    if not data or data == '' then
        ngx.log(ngx.DEBUG, 'skipping sending nil')
        return
    end

    return socket:send(data)
end

local function send_chunk(chunk)
    if not chunk then
        return nil
    end

    local ok, err = ngx.print(chunk)
    if not ok then
        return "output response failed: " .. (err or "")
    end

    return nil
end

-- forward_body reads chunks from a body_reader and passes them to the callback
-- function cb.
-- cb(chunk) should return a true on success, or nil/false, err on failure.
local function forward_body(reader, cb, chunksize)
  if not reader then
      return "no body reader"
  end

  local buffer_size = chunksize or 65536

  repeat
      local buffer, read_err, send_err
      buffer, read_err = reader(buffer_size)
      if read_err then
          return "failed to read response body: " .. read_err
      end

      if buffer then
          send_err = cb(buffer)
          if send_err then
              return "failed to send response body: " .. (send_err or "unknown")
          end
      end
  until not buffer
end

-- write_response writes response body reader to sock in the HTTP/1.x server response format,
-- The connection is closed if send() fails or when returning a non-zero
function _M.send_response(sock, response, chunksize)
    chunksize = chunksize or 65536

    if not response then
        ngx.log(ngx.ERR, "no response provided")
        return
    end

    if not sock then
        return "socket not initialized yet"
    end

    -- Build status line + headers into a single buffer to minimize send() calls
    local buf = {
        fmt("HTTP/1.1 %03d %s\r\n", response.status, response.reason)
    }

     -- Filter out hop-by-hop headeres
     for k, v in pairs(response.headers) do
        if not HOP_BY_HOP_HEADERS[str_lower(k)] then
          insert(buf, k .. ": " .. v .. cr_lf)
        end
     end

    -- End-of-header
    insert(buf, cr_lf)

    local bytes, err = sock:send(concat(buf))
    if not bytes then
        return "failed to send headers, err: " .. (err or "unknown")
    end

    return forward_body(response.body_reader, function(chunk)
        bytes, err = send(sock, chunk)
        if not bytes then
            return "failed to send response body, err: " .. (err or "unknown")
        end
    end, chunksize)
end

function _M.proxy_response(res, chunksize)
  if not res then
      ngx.log(ngx.ERR, "no response provided")
      return
  end

  ngx.status = res.status
  for k, v in pairs(res.headers) do
    if not HOP_BY_HOP_HEADERS[str_lower(k)] then
        ngx.header[k] = v
     end
  end

  return forward_body(res.body_reader, send_chunk, chunksize)
end

return _M
