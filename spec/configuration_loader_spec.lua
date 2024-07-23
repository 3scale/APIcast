local env = require 'resty.env'

insulate('Configuration object', function()

  insulate('.mock', function()
    local configuration = require 'apicast.configuration_loader'
    local mock_loader = require 'apicast.configuration_loader.mock'

    it('saves mock configuration', function()
      local config = { 'foo' }
      configuration.mock(config)

      assert.equal(config, mock_loader.config)
    end)
  end)

  describe('.init', function()
    local configuration = require 'apicast.configuration_loader'

    it('runs boot', function()
      local config, err = configuration.run_external_command('boot', 'gateway')

      assert.falsy(config)
      assert.match('missing configuration', err)
    end)
  end)

  describe('lazy', function()
    local configuration_loader = require 'apicast.configuration_loader'

    it('configures proxy on init', function()
      local config = {}
      local lazy = configuration_loader.new('lazy')

      assert.falsy(config.configured)
      lazy.init(config)
      assert.truthy(config.configured)
    end)
  end)


  describe('.configured', function()
    local _M = require('apicast.configuration_loader')
    local configuration_store = require('apicast.configuration_store')

    it('returns false when not configured', function()
      local configuration = {}
      assert.falsy(_M.configured(configuration))
    end)

    it('returns true when configured', function()
      local config = configuration_store.new()
      config:add({ id = 42, hosts = { 'example.com' } })

      assert.truthy(_M.configured(config, 'example.com'))
    end)

    it('returns false when configuration is stale', function()
      local config = configuration_store.new()

      -- Can't add stale info with config.add. Need to do it through the
      -- internals of the object.
      config.cache:set('example.com', { { id = 42, hosts = { 'example.com' } } }, -1)

      assert.falsy(_M.configured(config, 'example.com'))
    end)
  end)

  describe('.configure', function()
    local _M = require('apicast.configuration_loader')
    local configuration_store = require('apicast.configuration_store')
    local cjson = require('cjson')

    it('returns true with empty configuration', function()
      local config = configuration_store.new()
      assert.truthy(_M.configure(config, '{}'))
    end)

    it('returns true with blank configuration', function()
      local config = configuration_store.new()
      assert.is_nil(_M.configure(config, ''))
    end)

    it('stores the configuration', function()
      local config = configuration_store.new()

      assert.truthy(_M.configure(config, cjson.encode({ services = {
        { id = 42, proxy = { hosts = { 'localhost' } } }
      }})))

      assert.truthy(config:find_by_id('42'))
    end)

    it('should reset cache', function()
      local config = configuration_store.new()

      assert.truthy(_M.configure(config, cjson.encode({ services = {
        { id = 42, proxy = { hosts = { 'localhost' } } },
        { id = 43, proxy = { hosts = { 'localhost' } } }
      }})))

      assert.truthy(config:find_by_id('42'))
      assert.truthy(config:find_by_id('43'))

      assert.truthy(_M.configure(config, cjson.encode({ services = {
        { id = 42, proxy = { hosts = { 'localhost' } } },
      }}), true))
      assert.truthy(config:find_by_id('42'))
      assert.falsy(config:find_by_id('43'))
    end)
  end)

  describe('lazy loader', function()
    local _M = require('apicast.configuration_loader')
    local configuration_store = require('apicast.configuration_store')
    local loader

    before_each(function()
      loader = _M.new('lazy')

      -- By default, the config is reloaded on every rewrite(), because
      -- APICAST_CONFIGURATION_CACHE is set to 0. To be sure that it does not
      -- change and we can compare it, we need to set the env.
      env.set('APICAST_CONFIGURATION_CACHE', 120)
    end)

    it('does not crash on rewrite', function()
      local configuration = configuration_store.new()
      assert.same(configuration, loader.rewrite(configuration, 'example.com'))
    end)
  end)
end)
