--- Environment configuration
-- @module environment
-- This module is providing a configuration to APIcast before and during its initialization.
-- You can load several configuration files.
-- Fields from the ones added later override fields from the previous configurations.
local pl_path = require('pl.path')
local resty_env = require('resty.env')
local linked_list = require('apicast.linked_list')
local sandbox = require('resty.sandbox')
local util = require('apicast.util')
local setmetatable = setmetatable
local loadfile = loadfile
local require = require
local assert = assert
local print = print
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local open = io.open
local ceil = math.ceil
local insert = table.insert
local concat = table.concat
local re = require('ngx.re')


local function parse_nameservers()
    local resolver = require('resty.resolver')
    local nameservers = {}

    for _,nameserver in ipairs(resolver.init_nameservers()) do
        -- resty.resolver returns nameservers as tables with __tostring metamethod
        -- unfortunately those objects can't be joined with table.concat
        -- and have to be converted to strings first
        insert(nameservers, tostring(nameserver))
    end

    -- return the table only if there are some nameservers
    -- because it is way easier to check in liquid and `resolver` directive
    -- has to contain at least one server, so we can skip it when there are none
    if #nameservers > 0 then
        return nameservers
    end
end

-- CPU shares in Cgroups v1 or converted from weight in Cgroups v2 in millicores
local function cpu_shares()
  local shares

  -- This check is from https://github.com/kubernetes/kubernetes/blob/release-1.27/test/e2e/node/pod_resize.go#L305-L314
  -- alternatively, this method can be used: https://kubernetes.io/docs/concepts/architecture/cgroups/#check-cgroup-version
  -- (`stat -fc %T /sys/fs/cgroup/` returns `cgroup2fs` or `tmpfs`)
  if pl_path.exists("/sys/fs/cgroup/cgroup.controllers") then
    -- Cgroups v2
    ngx.log(ngx.DEBUG, "detecting cpus in Cgroups v2")
    -- Using the formula from https://github.com/kubernetes/kubernetes/blob/release-1.27/pkg/kubelet/cm/cgroup_manager_linux.go#L570-L574
    local file = open('/sys/fs/cgroup/cpu.weight')

    if file then
      local weight = file:read('*n')
      file:close()

      shares = (((weight - 1) * 262142) / 9999) + 2
    end
  else
    -- Cgroups v1
    ngx.log(ngx.DEBUG, "detecting cpus in Cgroups v1")
    local file = open('/sys/fs/cgroup/cpu/cpu.shares')

    if file then
      shares = file:read('*n')

      file:close()
    end
  end

  return shares
end

local function cpus()
    local shares = cpu_shares()
    if shares then
      local res = ceil(shares / 1024)
      ngx.log(ngx.DEBUG, "cpu_shares = "..res)
      return res
    end

    -- TODO: support /sys/fs/cgroup/cpuset/cpuset.cpus
    -- see https://github.com/sclorg/rhscl-dockerfiles/blob/ff912d8764af9a41096e63064bbc325395afa608/rhel7.sti-base/bin/cgroup-limits#L55-L75
    local nproc = util.system('nproc')
    ngx.log(ngx.DEBUG, "cpus from nproc = "..nproc)
    return tonumber(nproc)
end

local env_value_mt = {
    __tostring = function(t) return resty_env.value(t.name) end
}

local function env_value_ref(name)
    return setmetatable({ name = name }, env_value_mt)
end

local function read_opentracing_tracer(varname)
    local opentracing_tracer = env_value_ref(varname)

    if tostring(opentracing_tracer) ~= nil then
        ngx.log(ngx.WARN, 'opentracing use is DEPRECATED. Use Opentelemetry instead with OPENTELEMETRY env var')
    end

    return opentracing_tracer
end

local _M = {}
---
-- @field default_environment Default environment name.
-- @table self
_M.default_environment = 'production'

--- Default configuration.
-- @tfield ?string ca_bundle path to CA store file
-- @tfield ?string proxy_ssl_certificate path to SSL certificate
-- @tfield ?string proxy_ssl_certificate_key path to SSL certificate key
-- @tfield ?string proxy_ssl_session_reuse whether SSL sessions can be reused
-- @tfield ?string proxy_ssl_password_file path to a file with passphrases for the certificate keys
-- @tfield ?string opentracing_tracer loads an opentracing tracer library, for example: jaeger
-- @tfield ?string opentracing_config opentracing config file to load
-- @tfield ?string opentracing_forward_header opentracing http header to forward upstream
-- @tfield ?string opentelemetry enables server instrumentation using opentelemetry SDKs
-- @tfield ?string opentelemetry_config_file opentelemetry config file to load
-- @tfield ?string upstream_retry_cases error cases where the call to the upstream should be retried
--         follows the same format as https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream
-- @tfield ?policy_chain policy_chain @{policy_chain} instance
-- @tfield ?{string,...} nameservers list of nameservers
-- @tfield ?string package.path path to load Lua files
-- @tfield ?string package.cpath path to load libraries
-- @table environment.default_config default configuration

_M.default_config = {
    ca_bundle = env_value_ref('SSL_CERT_FILE'),
    proxy_ssl_certificate = env_value_ref('APICAST_PROXY_HTTPS_CERTIFICATE'),
    proxy_ssl_certificate_key = env_value_ref('APICAST_PROXY_HTTPS_CERTIFICATE_KEY'),
    proxy_ssl_session_reuse = env_value_ref('APICAST_PROXY_HTTPS_SESSION_REUSE'),
    proxy_ssl_password_file = env_value_ref('APICAST_PROXY_HTTPS_PASSWORD_FILE'),
    proxy_ssl_verify = resty_env.enabled('OPENSSL_VERIFY'),
    opentracing_tracer = read_opentracing_tracer('OPENTRACING_TRACER'),
    opentracing_config = env_value_ref('OPENTRACING_CONFIG'),
    opentracing_forward_header = env_value_ref('OPENTRACING_FORWARD_HEADER'),
    opentelemetry = env_value_ref('OPENTELEMETRY'),
    opentelemetry_config_file = env_value_ref('OPENTELEMETRY_CONFIG'),
    upstream_retry_cases = env_value_ref('APICAST_UPSTREAM_RETRY_CASES'),
    http_keepalive_timeout = env_value_ref('HTTP_KEEPALIVE_TIMEOUT'),
    policy_chain = require('apicast.policy_chain').default(),
    nameservers = parse_nameservers(),
    worker_processes = cpus() or 'auto',
    template = 'http.d/apicast.conf.liquid',
    package = {
        path = package.path,
        cpath = package.cpath,
    }
}

local mt = { __index = _M }

--- Return loaded environments defined as environment variable.
-- @treturn {string,...}
function _M.loaded()
    local value = resty_env.value('APICAST_LOADED_ENVIRONMENTS')
    return re.split(value or '', [[\|]], 'jo')
end

--- Load an environment from files in ENV.
-- @treturn Environment
function _M.load()
    local env = _M.new()
    local environments = _M.loaded()

    if not environments then
        return env
    end

    for i=1,#environments do
        assert(env:add(environments[i]))
    end

    return env
end

--- Initialize new environment.
-- @treturn Environment
function _M.new(context)
    return setmetatable({ _context = linked_list.readonly(_M.default_config, context), loaded = {} }, mt)
end

local function expand_environment_name(name)
    local root = resty_env.value('APICAST_DIR') or pl_path.abspath('.')
    local pwd = resty_env.value('PWD')

    local path = pl_path.abspath(name, pwd)
    local exists = pl_path.isfile(path)

    if exists then
        return nil, path
    end

    path = pl_path.join(root, 'config', ("%s.lua"):format(name))
    exists = pl_path.isfile(path)

    if exists then
        return name, path
    end
end

---------------------
--- @type Environment
-- An instance of @{environment} configuration.

--- Add an environment name or configuration file.
-- @tparam string env environment name or path to a file
function _M:add(env)
    local name, path = expand_environment_name(env)

    if self.loaded[path] then
        return true, 'already loaded'
    end

    if name and path then
        self.name = name
        print('loading ', name ,' environment configuration: ', path)
    elseif path then
        print('loading environment configuration: ', path)
    else
        return nil, 'no configuration found'
    end

    -- using sandbox is not strictly needed,
    -- but it is a nice way to add some extra env to the loaded code
    -- and not using global variables
    local box = sandbox.new()
    local config = loadfile(path, 't', setmetatable({
        inspect = require('inspect'), context = self._context,
        arg = arg, cli = arg,
        os = { getenv = resty_env.value },
    }, { __index = box.env }))

    if not config then
        return nil, 'invalid config'
    end

    self.loaded[path] = true

    self._context = linked_list.readonly(config(), self._context)

    return true
end

--- Read/write context
-- @treturn table context with all loaded environments combined
function _M:context()
    return linked_list.readwrite({ }, self._context)
end

--- Store loaded environment file names into ENV.
function _M:save()
    local environments = {}

    for file,_ in pairs(self.loaded) do
        insert(environments, file)
    end

    resty_env.set('APICAST_LOADED_ENVIRONMENTS', concat(environments, '|'))
end

return _M
