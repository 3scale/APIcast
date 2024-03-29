local co_yield = coroutine._yield
local co_wrap = coroutine._wrap
local open = io.open

local co_wrap_iter = require("resty.coroutines").co_wrap_iter

local chunk_size = 2^13 -- 8kb

local _M = {}

-- returns an iterator if the file is correct where can be read in chuinks of
-- 8kb.
-- If file cannot be open, it'll return nil function and the error message.
function _M.file_reader(filename)
    local handle, err = open(filename)
    if err then
      return nil, err
    end

    return co_wrap_iter(function()
      while true do
          local chunk = handle:read(chunk_size)
          if not chunk then
            break
          end
          co_yield(chunk)
      end
      handle:close()
    end)
end

function _M.file_size(filename)
    return co_wrap(function()
        local handle, err = open(filename)

        if err then
          return nil, err
        end

        local current = handle:seek()
        local size = handle:seek("end")

        handle:seek("set", current)
        handle:close()

        return size
    end)
end

return _M
