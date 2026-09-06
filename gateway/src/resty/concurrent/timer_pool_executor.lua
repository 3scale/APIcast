--- @module resty.concurrent

local setmetatable = setmetatable

local ngx_semaphore = require('ngx.semaphore')
local SafeTaskExecutor = require('resty.concurrent.safe_task_executor')
local Event = require('resty.concurrent.event')

--- @type TimerPoolExecutor
-- Execute tasks asynchronously in the background using ngx.timer.
local _M = { }
local mt = { __index = _M }

local no_options = {}

local fallback_policies = {
    abort = function() error('rejected execution', 2) end,
    discard = function() return false, 'rejected execution' end,
    caller_runs = function(fun, ...) return fun(...) end,
}

--- @static
--- @treturn TimerPoolExecutor
--- @tparam ?table options
--- @tparam nil|string|"abort"|"discard","caller_runs" options.fallback_policy
--- @number[opt=5] options.max_timers
function _M.new(options)
    local opts = options or no_options

    local max_timers = tonumber(opts.max_timers) or 5
    local fallback_policy = fallback_policies[opts.fallback_policy or 'abort'] or error('undefined fallback policy')
    local pool = ngx_semaphore.new(max_timers)

    return setmetatable({
        pool = pool,
        max_length = max_timers,
        fallback_policy = fallback_policy,
    }, mt)
end


local function checkout_timer(pool)
    return pool:wait(0)
end

local function checkin_timer(pool)
    pool:post(1)
end

local function worker(_, pool, event, task, ...)
    local success, _, reason = SafeTaskExecutor.execute(task,...)

    if not success then
        ngx.log(ngx.ERR, 'background task failed with: ', reason)
    end

    checkin_timer(pool)
    event:set()

    return
end

local function schedule(...)
    return ngx.timer.at(0, ...)
end

local function execute(pool, event, task, ...)
    local ok, err = schedule(worker, pool, event, task, ...)

    if not ok then
        ngx.log(ngx.ERR, 'failed to schedule background task: ', err)

        -- The timer was never created, so `worker` will never run to call
        -- checkin_timer()/event:set() for us. Do it here so callers waiting
        -- on the returned Event resolve immediately instead of blocking
        -- until their own wait() timeout expires.
        checkin_timer(pool)
        event:set()
    end
end

--- The number of running timers.
--- @function TimerPoolExecutor:__len
function mt:__len()
    local pool = self and self.pool
    if not pool then return nil, 'not initialized' end

    return self.max_length - pool:count()
end

--- Schedule task for execution.
--- @tparam function task
--- @param ... arguments
--- @treturn Event
--- @function TimerPoolExecutor:execute
function _M:post(task, ...)
    local pool = self and self.pool
    if not pool then return nil, 'not initialized' end

    if checkout_timer(pool) then
        -- schedule task
        local event = Event.new()
        execute(pool, event, task, ...)

        return event
    else
        return self.fallback_policy(task, ...)
    end
end

return _M
