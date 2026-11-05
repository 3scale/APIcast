local ReportsBatcher = require 'apicast.policy.3scale_batcher.reports_batcher'
local Usage = require 'apicast.usage'
local keys_helper = require 'apicast.policy.3scale_batcher.keys_helper'
local Transaction = require 'apicast.policy.3scale_batcher.transaction'
local resty_lock = require 'resty.lock'

describe('reports batcher', function()
  -- Records lock/unlock calls so the tests that care about them can assert on
  -- the order. Not relevant for most of these tests.
  local events

  before_each(function()
    events = {}

    stub(resty_lock, 'new').returns({
      lock = function() table.insert(events, 'lock') return true end,
      unlock = function() table.insert(events, 'unlock') return true end
    })
  end)

  describe('.add', function()
    local service_id = 's1'
    local credentials = { user_key = 'uk' }

    local usage = Usage.new()
    local metric = 'm1'
    usage:add(metric, 1)

    local transaction = Transaction.new(service_id, credentials, usage)

    local report_key = keys_helper.key_for_batched_report(service_id, credentials, metric)

    -- Note: all these tests use a mocked instance of ngx.shared.dict.
    -- 'safe_add()' returns 'no memory' when the dict ran out of memory and
    -- 'exists' when the key already exists in the dict.

    describe('when a report cannot be batched because the dict ran out of mem', function()
      it('does not try to increase the value of the batched report', function()
        local test_dict = {
          safe_add = function(_, _, _) return nil, 'no memory' end,
          incr = function(_, _, _) end
        }
        local spy_incr_dict = spy.on(test_dict, 'incr')
        local reports_batcher = ReportsBatcher.new(test_dict, 'batched_reports_locks')

        reports_batcher:add(transaction)

        assert.spy(spy_incr_dict).was_not_called()
      end)
    end)

    describe('when a report already exists in the dict', function()
      it('increases its usage', function()
        local test_dict = {
          safe_add = function(_, _, _) return nil, 'exists' end,
          incr = function(_, _, _) end
        }
        local spy_incr_dict = spy.on(test_dict, 'incr')
        local reports_batcher = ReportsBatcher.new(test_dict, 'batched_reports_locks')

        reports_batcher:add(transaction)

        assert.spy(spy_incr_dict).was_called_with(test_dict, report_key, 1)
      end)
    end)

    describe('when a report is not in the dict', function()
      it('adds it with the given usage', function()
        local test_dict = {
          safe_add = function(_, _, _) return true end,
          incr = function(_, _, _) end
        }
        local spy_add_dict = spy.on(test_dict, 'safe_add')
        local spy_incr_dict = spy.on(test_dict, 'incr')
        local reports_batcher = ReportsBatcher.new(test_dict, 'batched_reports_locks')

        reports_batcher:add(transaction)

        assert.spy(spy_add_dict).was_called.with(test_dict, report_key, 1)
        assert.spy(spy_incr_dict).was_not_called()
      end)
    end)
  end)

  describe('.get_all', function()
    describe('when a report has no credentials', function()
      it('does not crash', function()
        local service_id = '1'
        local report_key = keys_helper.key_for_batched_report(service_id, { app_id = '' }, 'foo')
        local storage = { [report_key] = 1 }
        local test_dict = {
          get_keys = function () return { report_key } end,
          get = function(_, key) return storage[key] end
        }

        local reports_batcher = ReportsBatcher.new(test_dict, 'batched_reports_locks')

        assert.same({}, reports_batcher:get_all('1'))
      end)
    end)

    it('reads the keys while holding the lock', function()
      -- There is one reporting timer per worker. Listing the keys before
      -- taking the lock lets another worker delete them in between.
      local test_dict = {
        get_keys = function() table.insert(events, 'get_keys') return {} end,
        get = function() end,
        delete = function() end
      }

      ReportsBatcher.new(test_dict, 'batched_reports_locks'):get_all('1')

      assert.same({ 'lock', 'get_keys', 'unlock' }, events)
    end)

    describe('when a key is gone after it has been listed', function()
      local service_id = '1'
      local credentials = { user_key = 'uk' }

      local missing_key = keys_helper.key_for_batched_report(
        service_id, credentials, 'missing')
      local existing_key = keys_helper.key_for_batched_report(
        service_id, credentials, 'existing')

      local function build_dict()
        local storage = { [existing_key] = 1 }

        return {
          get_keys = function() return { missing_key, existing_key } end,
          get = function(_, key) return storage[key] end,
          delete = function(_, key) storage[key] = nil end
        }
      end

      it('skips it and returns the remaining reports', function()
        local reports_batcher = ReportsBatcher.new(
          build_dict(), 'batched_reports_locks')

        local reports = reports_batcher:get_all(service_id)

        assert.equals(1, #reports)
        assert.equals('existing', reports[1].metric)
      end)

      it('releases the lock', function()
        ReportsBatcher.new(build_dict(), 'batched_reports_locks'):get_all(service_id)

        assert.same({ 'lock', 'unlock' }, events)
      end)
    end)
  end)
end)
