local setmetatable = setmetatable
local format = string.format
local len = string.len
local ipairs = ipairs
local insert = table.insert
local rawset = rawset
local tonumber = tonumber

local tablex = require('pl.tablex')
local deepcopy = tablex.deepcopy
local resty_url = require 'resty.url'
local http_ng = require "resty.http_ng"
local user_agent = require 'apicast.user_agent'
local cjson = require 'cjson.safe'
local resty_env = require 'resty.env'
local re = require 'ngx.re'
local configuration = require 'apicast.configuration'
local oidc_discovery = require('resty.oidc.discovery')
local match = ngx.re.match

local _M = {
  _VERSION = '0.1',
  _TYPE = "remote_v2"
}

local mt = {
  __index = _M
}

function _M.new(url, options)
  local endpoint = url or resty_env.get('THREESCALE_PORTAL_ENDPOINT')
  local ttl = tonumber(resty_env.value('APICAST_CONFIGURATION_CACHE') or 0)
  local opts = options or {}

  local http_client = http_ng.new{
    backend = opts.client,
    options = {
      headers = { ['User-Agent'] = user_agent() },
      ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') }
    }
  }
  local path = resty_url.split(endpoint or '')

  return setmetatable({
    endpoint = endpoint,
    path = path and path[6],
    options = opts,
    http_client = http_client,
    oidc = oidc_discovery.new_with_http_client(http_client),
    ttl = ttl
  }, mt)
end

local status_code_errors = setmetatable({
  [403] = 'invalid status: 403 (Forbidden)',
  [404] = 'invalid status: 404 (Not Found)'
}, {
  __index = function(t,k)
    local msg = format('invalid status: %s', k)
    rawset(t,k,msg)
    return msg
  end
})

local status_error_mt = {
  __tostring = function(t)
    return t.error
  end,
  __index = function(t,k)
    return t.response[k] or t.response.request[k]
  end
}

local function status_code_error(response)
  return setmetatable({
    error = status_code_errors[response.status],
    response = response
  }, status_error_mt)
end

local function array()
  return setmetatable({}, cjson.empty_array_mt)
end

local function services_index_endpoint(portal_endpoint)
  return resty_url.join(portal_endpoint, '/admin/api/services.json')
end

local function proxy_configs_index_endpoint(portal_endpoint, env)
  return resty_url.join(portal_endpoint, '/admin/api/account/proxy_configs/'..env..'.json')
end

local function service_config_endpoint(portal_endpoint, service_id, env, version)
  local version_override = resty_env.get(
      format('APICAST_SERVICE_%s_CONFIGURATION_VERSION', service_id)
  )

  return resty_url.join(
      portal_endpoint,
      '/admin/api/services/', service_id , '/proxy/configs/', env, '/',
      format('%s.json', version_override or version)
  )
end

local function get_oidc_issuer_endpoint(proxy_content)
  return proxy_content.proxy and proxy_content.proxy.oidc_issuer_endpoint
end

local function parse_proxy_configs(self, proxy_configs)
  local config = { services = array(), oidc = array() }

  for i, proxy_conf in ipairs(proxy_configs) do
    local proxy_config = proxy_conf.proxy_config
    local content = proxy_config.content

    config.services[i] = content

    local issuer_endpoint = get_oidc_issuer_endpoint(content)
    local oidc
    if issuer_endpoint then
      oidc = self.oidc:call(issuer_endpoint, self.ttl)
    end
    if not oidc then
      oidc = {}
    end

    -- deepcopy because this can be cached, and we want to have a deepcopy to
    -- avoid issues with service_id
    local oidc_copy = deepcopy(oidc)
    oidc_copy.service_id = tostring(content.id)

    config.oidc[i] = oidc_copy
  end
  return cjson.encode(config)
end

local function parse_resp_body(self, resp_body)
  local json, err = cjson.decode(resp_body)
  if not json then return nil, err end

  local proxy_configs = json.proxy_configs or {}

  return parse_proxy_configs(self, proxy_configs)
end

local function is_service_version_set()
  local vars = resty_env.list()
  for n, v in pairs(vars) do
    if match(n, "APICAST_SERVICE_\\d+_CONFIGURATION_VERSION") and v and v ~= '' then
        return true
    end
  end
  return false
end

function _M:index_per_service()
  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  local env = resty_env.value('THREESCALE_DEPLOYMENT_ENV')

  if not env then
    return nil, 'missing environment'
  end

  local configs = { services = array(), oidc = array() }

  local res, err = self:services()

  if not res and err then
    ngx.log(ngx.WARN, 'failed to get list of services: ', err, ' url: ', err.url)
    return nil, err
  end

  local service_regexp_filter  = resty_env.value("APICAST_SERVICES_FILTER_BY_URL")
  if service_regexp_filter then
    _, err = match("", service_regexp_filter, 'oj')
    if err then
      ngx.log(ngx.ERR, "APICAST_SERVICES_FILTER_BY_URL cannot compile, all services will be used: ", err)
      service_regexp_filter = nil
    end
  end

  local config
  for _, object in ipairs(res) do
    config, err = self:config(object.service, env, 'latest', service_regexp_filter)

    if config then
      insert(configs, config)
    else
      ngx.log(ngx.INFO, 'could not get configuration for service ', object.service.id, ': ', err)
    end
  end

  for i, conf in ipairs(configs) do
    configs.services[i] = conf.content

    -- Assign false instead of nil to avoid sparse arrays. cjson raises an
    -- error by default when converting sparse arrays.
    configs.oidc[i] = conf.oidc or false

    configs[i] = nil
  end

  return cjson.encode(configs)
end

function _M:index_custom_path(host)
  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  local env = resty_env.value('THREESCALE_DEPLOYMENT_ENV')

  if not env then
    return nil, 'missing environment'
  end

  -- http://${THREESCALE_PORTAL_ENDPOINT}/<env>.json?host=host
  local base_url = resty_url.join(self.endpoint, env..'.json')
  local encoded_args = ngx.encode_args({host = host})
  local query_args = encoded_args ~= '' and '?'..encoded_args
  local url = query_args and base_url..query_args or base_url

  local res, err = http_client.get(url)
  if res and res.status == 200 and res.body then
    ngx.log(ngx.DEBUG, 'index downloaded config from url: ', url)
    return parse_resp_body(self, res.body)
  elseif not res and err then
    ngx.log(ngx.DEBUG, 'index get error: ', err, ' url: ', url)
    return nil, err
  end

  ngx.log(ngx.DEBUG, 'index get status: ', res.status, ' url: ', url)

  return nil, 'invalid status'
end

-- Returns existing proxy configs in a single page
-- @param http_client the http client object
-- @param portal_endpoint 3scale API endpoint
-- @param host proxy config filter based on request hostname. Optional, can be nil.
-- @param env gateway environment
-- @param page page in the paginated list. Defaults to 1 for the API, as the client will not send the page param.
-- @param per_page number of results per page. Default and max is 500 for the API, as the client will not send the per_page param.
local function proxy_configs_per_page(http_client, portal_endpoint, host, page, per_page)
  local args = { host = host, version = "latest", page = page, per_page = per_page }

  local query_args = '?'..ngx.encode_args(args)
  local url = portal_endpoint..query_args

  -- http://${THREESCALE_PORTAL_ENDPOINT}/admin/api/account/proxy_configs/<env>.json?host=host&version=latest&page=1&per_page=500
  local res, err = http_client.get(url)

  if not res and err then
    ngx.log(ngx.DEBUG, 'proxy configs get error: ', err, ' url: ', url)
    return nil, err
  end

  ngx.log(ngx.DEBUG, 'proxy configs get status: ', res.status, ' url: ', url, ' body: ', res.body)

  if res and res.status == 200 and res.body then
    local json
    json, err = cjson.decode(res.body)
    if not json then return nil, err end

    return json.proxy_configs or array()
  else
    ngx.log(ngx.DEBUG, 'proxy configs get error: ', status_code_error(res), ' url: ', url)
    return nil, 'invalid status'
  end
end

function _M:index(host)
  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  local env = resty_env.value('THREESCALE_DEPLOYMENT_ENV')

  if not env then
    return nil, 'missing environment'
  end

  local PROXY_CONFIGS_PER_PAGE = 500
  -- Keep asking until the results length is different than "per_page" param
  -- If the 3scale API endpoint version does not support paginations AND
  -- the number of  results equals to PROXY_CONFIGS_PER_PAGE, the gateway will keep fetching
  -- configs indefinitely. The 3scale API endpoint version must support pagination to
  -- avoid endless loop.

  local all_results_per_page = false
  local current_page = 1
  local proxy_configs = array()
  local portal_endpoint = proxy_configs_index_endpoint(self.endpoint, env)

  repeat
    local page_proxy_configs, err = proxy_configs_per_page(http_client, portal_endpoint, host, current_page, PROXY_CONFIGS_PER_PAGE)
    if not page_proxy_configs and err then
      return nil, err
    end

    for _, proxy_config in ipairs(page_proxy_configs) do
      insert(proxy_configs, proxy_config)
    end

    all_results_per_page = #page_proxy_configs == PROXY_CONFIGS_PER_PAGE
    current_page = current_page + 1
  until(not  all_results_per_page)

  return parse_proxy_configs(self, proxy_configs)
end

function _M:call(host)
  if self == _M  or not self then
    local m = _M.new()
    return m:call(host)
  end

  local proxy_config_path = self.path

  -- uses proxy config specific endpoints unless APICAST_SERVICE_%s_CONFIGURATION_VERSION
  -- When specific version for a specific service is defined,
  -- loading services one by one is required
  --
  -- APICAST_SERVICE_%s_CONFIGURATION_VERSION does not work when the THREESCALE_PORTAL_ENDPOINT
  -- points to master (the API does not allow it), hence error is returned

  local use_service_version = is_service_version_set()

  if use_service_version and proxy_config_path then
    return nil, 'APICAST_SERVICE_%s_CONFIGURATION_VERSION cannot be used when proxy config path is provided'
  end

  if use_service_version then
    return self:index_per_service()
  elseif proxy_config_path then
    return self:index_custom_path(host)
  else
    return self:index(host)
  end
end

local function services_subset()
  local services = resty_env.value('APICAST_SERVICES_LIST') or resty_env.value('APICAST_SERVICES')
  if resty_env.value('APICAST_SERVICES') then ngx.log(ngx.WARN, 'DEPRECATION NOTICE: Use APICAST_SERVICES_LIST not APICAST_SERVICES as this will soon be unsupported') end
  if services and len(services) > 0 then
    local ids, err = re.split(services, ',', 'oj')
    if not ids then
      return nil, err
    end

    for i=1, #ids do
      ids[i] = { service = { id = tonumber(ids[i]) } }
    end
    return ids
  end
end


-- Returns existing services in a single page
-- @param http_client the http client object
-- @param portal_endpoint 3scale API endpoint
-- @param page page in the paginated list. Defaults to 1 for the API, as the client will not send the page param.
-- @param per_page number of results per page. Default and max is 500 for the API, as the client will not send the per_page param.
local function services_per_page(http_client, portal_endpoint, page, per_page)
  local encoded_args = ngx.encode_args({page = page, per_page = per_page})
  local query_args = encoded_args ~= '' and '?'..encoded_args
  local url = query_args and portal_endpoint..query_args or portal_endpoint

  local res, err = http_client.get(url)

  if not res and err then
    ngx.log(ngx.DEBUG, 'services get error: ', err, ' url: ', url)
    return nil, err
  end

  ngx.log(ngx.DEBUG, 'services get status: ', res.status, ' url: ', url, ' body: ', res.body)

  if res.status == 200 then
    local json
    json, err = cjson.decode(res.body)
    if not json then return nil, err end

    return json.services or array()
  else
    return nil, status_code_error(res)
  end
end

-- Returns a table with services.
-- There are 2 cases:
-- A) with APICAST_SERVICES_LIST. The method returns a table where each element
--    contains a single field "service", which is another table with just one
--    element: "id".
--    Example: { { service = { id = 123 } }, { service = { id = 456 } } }
-- B) without APICAST_SERVICES_LIST. The services are fetched from an endpoint
--    in Porta: https://ACCESS-TOKEN@ADMIN-DOMAIN/admin/api/services.json
--    The function returns the services decoded as Lua tables.
--    Each element follows the same format described above, but instead of
--    having just "id", there are other fields: "backend_version",
--    "created_at", "state", "system_name", and other fields.
function _M:services()
  local services = services_subset()
  if services then return services end

  local http_client = self.http_client

  if not http_client then
    return nil, 'not initialized'
  end

  local endpoint = self.endpoint

  if not endpoint then
    return nil, 'no endpoint'
  end

  local SERVICES_PER_PAGE = 500
  -- Keep asking until the results length is different than "per_page" param
  -- If the 3scale API endpoint version does not support paginations AND
  -- the number of  results equals to SERVICES_PER_PAGE, the gateway will keep fetching
  -- services indefinitely. The 3scale API endpoint version must support pagination to
  -- avoid endless loop.

  local all_results_per_page = false
  local current_page = 1
  local services = array()
  local service_endpoint = services_index_endpoint(endpoint)

  repeat
    local page_services, err = services_per_page(http_client, service_endpoint, current_page, SERVICES_PER_PAGE)
    if not page_services and err then
      return nil, err
    end

    for _, service in ipairs(page_services) do
      insert(services, service)
    end

    all_results_per_page = #page_services == SERVICES_PER_PAGE
    current_page = current_page + 1
  until(not  all_results_per_page)

  return services
end

function _M:oidc_issuer_configuration(service)
  return self.oidc:call(service.oidc.issuer_endpoint, self.ttl)
end

function _M:config(service, environment, version, service_regexp_filter)
  local http_client = self.http_client

  if not http_client then return nil, 'not initialized' end

  local endpoint = self.endpoint
  if not endpoint then return nil, 'no endpoint' end

  local id = service and service.id

  if not id then return nil, 'invalid service, missing id' end
  if not environment then return nil, 'missing environment' end
  if not version then return nil, 'missing version' end

  local url = service_config_endpoint(endpoint, id, environment, version)

  local res, err = http_client.get(url)

  if not res and err then
    ngx.log(ngx.ERR, 'services get error: ', err, ' url: ', url)
    return nil, err
  end

  ngx.log(ngx.DEBUG, 'services get status: ', res.status, ' url: ', url, ' body: ', res.body)

  if res.status == 200 then
    local proxy_config = cjson.decode(res.body).proxy_config
    local content = proxy_config.content

    local config_service = configuration.parse_service(proxy_config.content)
    if service_regexp_filter and not config_service:match_host(service_regexp_filter) then
      return nil, "Service filtered out because APICAST_SERVICES_FILTER_BY_URL"
    end

    local issuer_endpoint = get_oidc_issuer_endpoint(content)
    local oidc

    if issuer_endpoint then
      oidc = self.oidc:call(issuer_endpoint, self.ttl)
    end

    proxy_config.oidc = oidc
    return proxy_config
  else
    return nil, status_code_error(res)
  end
end

return _M
