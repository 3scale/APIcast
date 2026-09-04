local TimerPoolExecutor = require('resty.concurrent.timer_pool_executor')

local timeout = 10
local noop = function() end

-- checkin_timer() always runs before event:set() inside the worker (see
-- timer_pool_executor.lua), so by the time :wait() returns, the checkin has
-- already happened in-process. But the worker's checkin/timer bookkeeping
-- can still take an extra event-loop tick to become visible under
-- scheduler/CI load, and this test was flaky for years with a single fixed
-- `ngx.sleep(0)` yield before asserting. Poll with a bounded timeout instead
-- of asserting after exactly one yield, so the test tolerates scheduler
-- timing variance without weakening what it verifies.
local function wait_until(predicate, timeout_seconds)
    local deadline = ngx.now() + (timeout_seconds or 1)

    repeat
        if predicate() then return true end
        ngx.sleep(0.01)
    until ngx.now() >= deadline

    return predicate()
end

describe('TimerPoolExecutor', function()
    describe('worker garbage collection', function()
        it('automatically checks in back old workers', function()
            local pool = TimerPoolExecutor.new({ max_timers = 1 })

            assert(pool:post(noop):wait(timeout))
            assert(wait_until(function() return #pool == 0 end))
            assert(pool:post(noop):wait(timeout))
        end)

        it('puts back worker even when task crashes', function ()
            local pool = TimerPoolExecutor.new({ max_timers = 1 })

            assert(pool:post(error, 'message'):wait(timeout))
            assert(wait_until(function() return #pool == 0 end))
            assert(pool:post(error, 'message'):wait(timeout))
        end)

        it('resolves the event immediately when ngx.timer.at fails to schedule', function()
            stub(ngx.timer, 'at', function() return nil, 'too many pending timers' end)

            local pool = TimerPoolExecutor.new({ max_timers = 1 })
            local event = pool:post(noop)

            -- should resolve right away rather than blocking until the
            -- caller-supplied wait() timeout expires.
            assert(event:wait(0.5))
            assert.equal(0, #pool)
        end)
    end)

    describe('fallback policies', function()
        it('can discard tasks', function()
            local pool = TimerPoolExecutor.new({ max_timers = 0, fallback_policy = 'discard' })

            assert.returns_error('rejected execution', pool:post(noop))
        end)

        it('can throw error', function()
            local pool = TimerPoolExecutor.new({ max_timers = 0, fallback_policy = 'abort' })

            assert.has_error(function() pool:post(noop) end, 'rejected execution')
        end)

        it('can run within the caller', function()
            local pool = TimerPoolExecutor.new({ max_timers = 0, fallback_policy = 'caller_runs' })
            local task = spy.new(function () return coroutine.running() end)

            assert(pool:post(task))

            assert.spy(task).was_called(1)
            assert.spy(task).was_returned_with(coroutine.running())
        end)
    end)
end)
