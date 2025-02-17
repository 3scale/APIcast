-- JWT Parser policy
-- It will verify JWT signature against a list of public keys
-- discovered through OIDC Discovery from the IDP.

local lrucache = require('resty.lrucache')
local OIDC = require('apicast.oauth.oidc')
local oidc_discovery = require('resty.oidc.discovery')
local http_authorization = require('resty.http_authorization')
local resty_url = require('resty.url')
local policy = require('apicast.policy')
local _M = policy.new('jwt_parser', 'builtin')

local tostring = tostring

_M.cache_size = 100

function _M.init()
  _M.cache = lrucache.new(_M.cache_size)
end

local function valid_issuer_endpoint(endpoint)
  return resty_url.parse(endpoint) and endpoint
end

local new = _M.new
--- Initialize jwt_parser policy
-- @tparam[opt] table config Policy configuration.
function _M.new(config)
  local self = new(config)

  self.issuer_endpoint = valid_issuer_endpoint(config and config.issuer_endpoint)
  self.discovery = oidc_discovery.new(self.http_backend)

  self.oidc = (config and config.oidc) or OIDC.new(self.discovery:call(self.issuer_endpoint))

  self.required = config and config.required

  return self
end

local function bearer_token()
  return http_authorization.new(ngx.var.http_authorization).token
end

local function exit_status(status)
  ngx.status = status
  -- TODO: implement content negotiation to generate proper content with an error
  return ngx.exit(status)
end

local function challenge_response(status)
  ngx.header.www_authenticate = 'Bearer'

  return exit_status(status)
end

local function check_compatible(context)
  local service = context.service or {}
  local authentication = service.authentication_method or service.backend_version
  if authentication == "oidc" or authentication == "oauth" then
    ngx.log(ngx.WARN, 'jwt_parser is incompatible with OIDC authentication mode')
    return false
  end
  return true
end

function _M:rewrite(context)
  if not check_compatible(context) then
    return
  end

  local access_token = bearer_token()

  if not access_token then
    if self.required then
        return challenge_response(context.service.auth_failed_status)
    end
  end

  if access_token then
    local _, _, jwt_payload, err = self.oidc:transform_credentials({access_token=access_token})

    if jwt_payload then
      context.jwt = jwt_payload
    else
      ngx.log(ngx.WARN, 'failed to parse access token ', access_token, ' err: ', err)
      if self.required then
        return exit_status(context.service.auth_failed_status)
      end
    end
  end
end

return _M
