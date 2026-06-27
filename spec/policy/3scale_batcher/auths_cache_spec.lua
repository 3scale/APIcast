local AuthsCache = require 'apicast.policy.3scale_batcher.auths_cache'
local Usage = require 'apicast.usage'
local Transaction = require 'apicast.policy.3scale_batcher.transaction'
local lrucache =require 'resty.lrucache'

local storage
local cache
local usage

local service_id = 's1'
local auth_status = 200

describe('Auths cache', function()
  before_each(function()
    storage = lrucache.new(100)
    cache = AuthsCache.new(storage)

    usage = Usage.new()
    usage:add('m1', 1)
  end)

  it('caches auth with user key', function()
    local user_key = { user_key = 'uk' }
    local transaction = Transaction.new(service_id, user_key, usage)

    cache:set(transaction, auth_status)

    local cached_status = cache:get(transaction)
    assert.equals(auth_status, cached_status)
  end)

  it('caches auth with app id + app key', function()
    local app_id_and_key = { app_id = 'an_id', app_key = 'a_key' }
    local transaction = Transaction.new(service_id, app_id_and_key, usage)

    cache:set(transaction, auth_status)

    local cached_status = cache:get(transaction)
    assert.equals(auth_status, cached_status)
  end)

  it('caches auth with access token', function()
    local access_token = { access_token = 'a_token' }
    local transaction = Transaction.new(service_id, access_token, usage)

    cache:set(transaction, auth_status)

    local cached_status = cache:get(transaction)
    assert.equals(auth_status, cached_status)
  end)

  it('caches auths with same usages but different order in the same key', function()
    local usage_order_1 = Usage.new()
    usage_order_1:add('m1', 1)
    usage_order_1:add('m2', 1)

    local usage_order_2 = Usage.new()
    usage_order_2:add('m2', 1)
    usage_order_2:add('m1', 1)

    local user_key = { user_key = 'uk' }

    local transaction_with_order_1 = Transaction.new(service_id, user_key, usage_order_1)
    local transaction_with_order_2 = Transaction.new(service_id, user_key, usage_order_2)

    cache:set(transaction_with_order_1, auth_status)

    local cached_status = cache:get(transaction_with_order_2)
    assert.equals(auth_status, cached_status)
  end)

  it('caches a rejection reason when given', function()
    local rejection_reason = 'limits_exceeded'
    local app_id_and_key = { app_id = 'an_id', app_key = 'a_key' }
    local transaction = Transaction.new(service_id, app_id_and_key, usage)
    local not_authorized_status = 409

    cache:set(transaction, not_authorized_status, rejection_reason)

    local cached_status, cached_rejection_reason = cache:get(transaction)
    assert.equals(not_authorized_status, cached_status)
    assert.equals(rejection_reason, cached_rejection_reason)
  end)

  it('returns nil when something is not cached', function()
    local user_key = { user_key = 'uk' }
    local transaction = Transaction.new(service_id, user_key, usage)
    

    assert.is_nil(cache:get(transaction))
  end)

  it('returns status without rejection_reason when cached without one', function()
    local user_key = { user_key = 'uk' }
    local transaction = Transaction.new(service_id, user_key, usage)

    cache:set(transaction, auth_status)

    local cached_status, cached_rejection_reason = cache:get(transaction)
    assert.equals(auth_status, cached_status)
    assert.is_nil(cached_rejection_reason)
  end)

  it('parses rejection reason containing colons', function()
    local app_id_and_key = { app_id = 'an_id', app_key = 'a_key' }
    local transaction = Transaction.new(service_id, app_id_and_key, usage)
    local rejection_reason = 'reason:with:colons'

    cache:set(transaction, 409, rejection_reason)

    local cached_status, cached_rejection_reason = cache:get(transaction)
    assert.equals(409, cached_status)
    assert.equals(rejection_reason, cached_rejection_reason)
  end)

  it('returns correct status for different HTTP status codes', function()
    local user_key = { user_key = 'uk' }

    for _, status_code in ipairs({ 200, 403, 404, 409, 500 }) do
      local tx_usage = Usage.new()
      tx_usage:add('m_' .. status_code, 1)
      local transaction = Transaction.new(service_id, user_key, tx_usage)

      cache:set(transaction, status_code)

      local cached_status, cached_rejection_reason = cache:get(transaction)
      assert.equals(status_code, cached_status)
    end
  end)
end)
