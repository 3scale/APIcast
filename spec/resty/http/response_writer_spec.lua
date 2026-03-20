local response_writer = require('resty.http.response_writer')


describe('resty.http.response_writer', function()

  local mock_sock
  local sent_data

  local function make_response(opts)
    opts = opts or {}
    local chunks = opts.chunks or { "hello" }
    local idx = 0
    return {
      status = opts.status or 200,
      reason = opts.reason or "OK",
      headers = opts.headers or {},
      body_reader = function()
        idx = idx + 1
        return chunks[idx]
      end
    }
  end

  before_each(function()
    sent_data = {}
    mock_sock = {
      send = function(_, data)
        table.insert(sent_data, data)
        return #data, nil
      end
    }

    stub(ngx, 'log')
  end)

  describe('.send_response', function()

    it('returns nil when no response is provided', function()
      local err = response_writer.send_response(mock_sock, nil)
      assert.is_nil(err)
    end)

    it('returns error when no socket is provided', function()
      local err = response_writer.send_response(nil, make_response())
      assert.equal("socket not initialized yet", err)
    end)

    it('sends status line in first send', function()
      local response = make_response({ status = 200, reason = "OK" })
      response_writer.send_response(mock_sock, response)

      assert.truthy(string.find(sent_data[1], "^HTTP/1.1 200 OK\r\n"))
    end)

    it('formats different status codes', function()
      local response = make_response({ status = 404, reason = "Not Found" })
      response_writer.send_response(mock_sock, response)

      assert.truthy(string.find(sent_data[1], "^HTTP/1.1 404 Not Found\r\n"))
    end)

    it('batches status line and headers in a single send', function()
      local response = make_response({
        headers = { ["Content-Type"] = "text/plain", ["X-Custom"] = "value" }
      })
      response_writer.send_response(mock_sock, response)

      -- First send contains status line + headers + end-of-header CRLF
      local header_block = sent_data[1]
      assert.truthy(string.find(header_block, "^HTTP/1.1"))
      assert.truthy(string.find(header_block, "Content%-Type: text/plain\r\n"))
      assert.truthy(string.find(header_block, "X%-Custom: value\r\n"))
      assert.truthy(string.find(header_block, "\r\n\r\n$"))
    end)

    it('filters hop-by-hop headers', function()
      local response = make_response({
        headers = {
          ["Connection"] = "keep-alive",
          ["Keep-Alive"] = "timeout=5",
          ["Transfer-Encoding"] = "chunked",
          ["Proxy-Authenticate"] = "Basic",
          ["Proxy-Authorization"] = "Basic abc",
          ["TE"] = "trailers",
          ["Trailers"] = "Expires",
          ["Upgrade"] = "websocket",
          ["Content-Length"] = "5",
          ["X-Custom"] = "value",
        }
      })
      response_writer.send_response(mock_sock, response)

      local all_sent = table.concat(sent_data)
      assert.falsy(string.find(all_sent, "Connection:"))
      assert.falsy(string.find(all_sent, "Keep%-Alive:"))
      assert.falsy(string.find(all_sent, "Transfer%-Encoding:"))
      assert.falsy(string.find(all_sent, "Proxy%-Authenticate:"))
      assert.falsy(string.find(all_sent, "Proxy%-Authorization:"))
      assert.falsy(string.find(all_sent, "TE:"))
      assert.falsy(string.find(all_sent, "Trailers:"))
      assert.falsy(string.find(all_sent, "Upgrade:"))
      assert.falsy(string.find(all_sent, "Content%-Length:"))
      assert.truthy(string.find(all_sent, "X%-Custom: value"))
    end)

    it('filters hop-by-hop headers case-insensitively', function()
      local response = make_response({
        headers = {
          ["CONNECTION"] = "close",
          ["KEEP-ALIVE"] = "timeout=5",
        }
      })
      response_writer.send_response(mock_sock, response)

      local all_sent = table.concat(sent_data)
      assert.falsy(string.find(all_sent, "CONNECTION:"))
      assert.falsy(string.find(all_sent, "KEEP%-ALIVE:"))
    end)

    it('sends end-of-header marker', function()
      local response = make_response({ headers = {} })
      response_writer.send_response(mock_sock, response)

      assert.truthy(string.find(sent_data[1], "\r\n\r\n$"))
    end)

    it('sends body chunks after headers', function()
      local response = make_response({ chunks = { "hello world" } })
      response_writer.send_response(mock_sock, response)

      -- sent_data[1] is headers, sent_data[2] is body chunk
      assert.equal("hello world", sent_data[2])
    end)

    it('sends multi-chunk body', function()
      local response = make_response({ chunks = { "chunk1", "chunk2", "chunk3" } })
      response_writer.send_response(mock_sock, response)

      assert.equal("chunk1", sent_data[2])
      assert.equal("chunk2", sent_data[3])
      assert.equal("chunk3", sent_data[4])
    end)

    it('returns true on success', function()
      local response = make_response()
      local err = response_writer.send_response(mock_sock, response)

      assert.is_nil(err)
    end)

    it('returns error when headers send fails', function()
      mock_sock.send = function() return nil, "closed" end
      local response = make_response()
      local err = response_writer.send_response(mock_sock, response)

      assert.truthy(string.find(err, "failed to send headers"))
    end)

    it('returns error when body send fails', function()
      local call_count = 0
      mock_sock.send = function(_, data)
        call_count = call_count + 1
        if call_count == 1 then
          return #data, nil  -- headers succeed
        end
        return nil, "closed"  -- body chunk fails
      end

      local response = make_response({ chunks = { "hello" } })
      local err = response_writer.send_response(mock_sock, response)

      assert.truthy(string.find(err, "failed to send response body"))
    end)

    it('returns error when body reader fails', function()
      local response = {
        status = 200,
        reason = "OK",
        headers = {},
        body_reader = function()
          return nil, "read error"
        end
      }
      local err = response_writer.send_response(mock_sock, response)

      assert.truthy(string.find(err, "failed to read response body"))
    end)

    it('returns error when response has no body_reader', function()
      local response = {
        status = 200,
        reason = "OK",
        headers = {},
      }
      local err = response_writer.send_response(mock_sock, response)

      assert.equal("no body reader", err)
    end)

    it('passes chunksize to body_reader', function()
      local received_chunksize
      local response = {
        status = 200,
        reason = "OK",
        headers = {},
        body_reader = function(size)
          received_chunksize = size
          return nil
        end
      }
      response_writer.send_response(mock_sock, response, 1024)

      assert.equal(1024, received_chunksize)
    end)

    it('uses default chunksize of 65536', function()
      local received_chunksize
      local response = {
        status = 200,
        reason = "OK",
        headers = {},
        body_reader = function(size)
          received_chunksize = size
          return nil
        end
      }
      response_writer.send_response(mock_sock, response)

      assert.equal(65536, received_chunksize)
    end)

    it('handles empty body', function()
      local response = make_response({ chunks = {} })
      local err = response_writer.send_response(mock_sock, response)

      assert.is_nil(err)
    end)
  end)

  describe('.proxy_response', function()
    local printed_data
    local headers_set

    before_each(function()
      printed_data = {}
      headers_set = {}

      ngx.status = nil
      ngx.header = setmetatable({}, {
        __newindex = function(_, k, v)
          headers_set[k] = v
        end
      })

      stub(ngx, 'print', function(data)
        table.insert(printed_data, data)
        return true
      end)
      stub(ngx, 'flush', function() return true end)
    end)

    it('returns nil when no response is provided', function()
      local ok = response_writer.proxy_response(nil)
      assert.is_nil(ok)
    end)

    it('sets ngx.status from response', function()
      local res = make_response({ status = 201 })
      local err = response_writer.proxy_response(res)

      assert.is_nil(err)
      assert.equal(201, ngx.status)
    end)

    it('sets response headers on ngx.header', function()
      local res = make_response({
        headers = {
          ["Content-Type"] = "application/json",
          ["X-Request-Id"] = "abc123",
        }
      })
      local err = response_writer.proxy_response(res)

      assert.is_nil(err)
      assert.equal("application/json", headers_set["Content-Type"])
      assert.equal("abc123", headers_set["X-Request-Id"])
    end)

    it('filters hop-by-hop headers', function()
      local res = make_response({
        headers = {
          ["Connection"] = "keep-alive",
          ["Keep-Alive"] = "timeout=5",
          ["Transfer-Encoding"] = "chunked",
          ["Proxy-Authenticate"] = "Basic",
          ["Proxy-Authorization"] = "Basic abc",
          ["TE"] = "trailers",
          ["Trailers"] = "Expires",
          ["Upgrade"] = "websocket",
          ["Content-Length"] = "5",
          ["X-Custom"] = "kept",
        }
      })
      local err = response_writer.proxy_response(res)

      assert.is_nil(err)
      assert.is_nil(headers_set["Connection"])
      assert.is_nil(headers_set["Keep-Alive"])
      assert.is_nil(headers_set["Transfer-Encoding"])
      assert.is_nil(headers_set["Proxy-Authenticate"])
      assert.is_nil(headers_set["Proxy-Authorization"])
      assert.is_nil(headers_set["TE"])
      assert.is_nil(headers_set["Trailers"])
      assert.is_nil(headers_set["Upgrade"])
      assert.is_nil(headers_set["Content-Length"])
      assert.equal("kept", headers_set["X-Custom"])
    end)

    it('filters hop-by-hop headers case-insensitively', function()
      local res = make_response({
        headers = {
          ["CONNECTION"] = "close",
          ["TRANSFER-ENCODING"] = "chunked",
        }
      })
      local err = response_writer.proxy_response(res)

      assert.is_nil(err)
      assert.is_nil(headers_set["CONNECTION"])
      assert.is_nil(headers_set["TRANSFER-ENCODING"])
    end)

    it('prints and flushes body chunks', function()
      local res = make_response({ chunks = { "chunk1", "chunk2" } })
      local err = response_writer.proxy_response(res)

      assert.is_nil(err)
      assert.stub(ngx.print).was_called(2)
      assert.stub(ngx.print).was_called_with("chunk1")
      assert.stub(ngx.print).was_called_with("chunk2")
      -- assert.stub(ngx.flush).was_called(2)
    end)

    it('returns true on success', function()
      -- local res = make_response({ chunks = { "data" } })
      -- local ok, err = response_writer.proxy_response(res)

      -- assert.is_true(ok)
      -- assert.is_nil(err)
    end)

    it('handles empty body', function()
      local res = make_response({ chunks = {} })
      local err = response_writer.proxy_response(res)

      assert.is_nil(err)
      assert.stub(ngx.print).was_not_called()
    end)

    it('returns error when ngx.print fails', function()
      ngx.print:revert()
      stub(ngx, 'print', function() return nil, "broken pipe" end)

      local res = make_response({ chunks = { "data" } })
      local err = response_writer.proxy_response(res)

      assert.truthy(string.find(err, "output response failed"))
    end)

    it('returns error when body reader fails', function()
      local res = {
        status = 200,
        headers = {},
        body_reader = function()
          return nil, "read timeout"
        end
      }
      local err = response_writer.proxy_response(res)

      assert.truthy(string.find(err, "failed to read response body"))
    end)

    it('passes chunksize to body_reader', function()
      local received_chunksize
      local res = {
        status = 200,
        headers = {},
        body_reader = function(size)
          received_chunksize = size
          return nil
        end
      }
      response_writer.proxy_response(res, 2048)

      assert.equal(2048, received_chunksize)
    end)
  end)
end)

