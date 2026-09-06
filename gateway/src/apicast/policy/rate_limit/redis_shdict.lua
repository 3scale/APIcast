local ts = require ('apicast.threescale_utils')

local setmetatable = setmetatable
local tonumber = tonumber

local _M = {

}

local mt = { __index = _M }

function _M.new(options)
    local redis, err = ts.connect_redis(options)
    if not redis then
        return nil, err
    end

    return setmetatable({
        redis = redis
    }, mt)
end

function _M:incr(key, value, init, init_ttl)
    local redis = self.redis
    if not redis then return nil, 'not initialized' end

    if not init then
        -- Unlike Redis' INCRBY (which auto-vivifies a missing key at 0),
        -- ngx.shared.DICT:incr() without an init value returns `nil, 'not
        -- found'` for a missing key. Callers (e.g. resty.limit.count-inc's
        -- and resty.limit.conn's rollback/uncommit logic) rely on that
        -- contract to detect an already-expired/evicted key instead of
        -- silently recreating it with no TTL.
        local exists, err = redis:exists(key)
        if exists == nil then return nil, err end
        if exists == 0 then return nil, 'not found' end

        return redis:incrby(key, value), nil
    end

    local ok, err = redis:multi()
    if not ok then return nil, err end

    ok, err = redis:setnx(key, init)
    if not ok then return nil, err end

    if init_ttl then
        ok, err = redis:expire(key, init_ttl)
        if not ok then return nil, err end
    end

    ok, err = redis:incrby(key, value)
    if not ok then return nil, err end

    ok, err = redis:exec()
    if not ok then return nil, err end

    return ok[#ok]
end

function _M:set(key, value)
    local redis = self.redis
    if not redis then return nil, 'not initialized' end

    return redis:set(key, value)
end

function _M:expire(key, exptime)
    local redis = self.redis
    if not redis then return nil, 'not initialized' end

    local ret = redis:expire(key, exptime)
    if ret == 0 then
        return nil, "not found"
    end
    return true, nil
end

function _M:get(key)
    local redis = self.redis
    if not redis then return nil, 'not initialized' end

    local val = redis:get(key)

    if val == ngx.null then
        return nil
    end

    return tonumber(val) or val
end

function _M:flush_all()
    local redis = self.redis
    if not redis then return nil, 'not initialized' end

    redis:flushdb()
end

return _M
