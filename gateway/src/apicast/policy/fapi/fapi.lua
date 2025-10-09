--- Financial-grade API (FAPI) policy
-- Current support the following profile:
--    FAPI 1.0 - Baseline profile
--    FAPI 1.0 - Advance profile

local policy = require('apicast.policy')
local _M = policy.new('Financial-grade API (FAPI) Policy', 'builtin')

local uuid = require 'resty.jit-uuid'
local ipmatcher = require "resty.ipmatcher"
local X509 = require('resty.openssl.x509')
local b64 = require('ngx.base64')
local fmt = string.format

local new = _M.new
local X_FAPI_INTERACTION_ID_HEADER = "x-fapi-interaction-id"
local X_FAPI_CUSTOMER_IP_ADDRESS = "x-fapi-customer-ip-address"

-- The "x5t#S256" (X.509 Certificate SHA-256 Thumbprint) Header
-- Parameter is a base64url encoded SHA-256 thumbprint (a.k.a. digest)
-- of the DER encoding of the X.509 certificate.
-- https://tools.ietf.org/html/rfc7515#section-4.1.8
local header_parameter = 'x5t#S256'

local function is_valid_ip(ip)
  if type(ip) ~= "string" then
    return false
  end
  if ipmatcher.parse_ipv4(ip) then
    return true
  end

  return ipmatcher.parse_ipv6(ip)
end

local function error(status_code, msg)
  ngx.status = status_code
  ngx.header.content_type = 'application/json; charset=utf-8'
  ngx.print(fmt('{"error": "%s"}', msg))
  ngx.exit(ngx.status)
end

-- https://datatracker.ietf.org/doc/html/rfc8705#name-jwt-certificate-thumbprint-
local function check_certificate(cert, cnf)
  if not cert then
    ngx.log(ngx.DEBUG, "client certificate is not available")
    return false
  end

  if not cnf then
    ngx.log(ngx.DEBUG, "cnf claim is not available")
    return false
  end
  return b64.encode_base64url(cert:digest('SHA256')) == cnf[header_parameter]
end

--- Initialize FAPI policy
-- @tparam[config] table config
-- @field[config] validate_x_fapi_customer_ip_address Boolean
-- @field[config] validate_oauth2_certificate_bound_access_token Boolean
function _M.new(config)
  local self = new(config)
  self.validate_customer_ip_address = config and config.validate_x_fapi_customer_ip_address
  self.validate_oauth2_certificate_bound_access_token = config and config.validate_oauth2_certificate_bound_access_token
  return self
end

function _M:access(context)
  if self.validate_oauth2_certificate_bound_access_token then
    if not context.jwt then return error(context.service or {}) end

    local cert = X509.new(ngx.var.ssl_client_raw_cert)

    if not check_certificate(cert, context.jwt.cnf) then
      ngx.log(ngx.WARN, 'fapi oauth_mtls failed for service ', context.service and context.service.id)
      return error(ngx.HTTP_UNAUTHORIZED, "invalid_token")
    end
  end

  --- 6.2.1.13
  -- shall not reject requests with a x-fapi-customer-ip-address header containing a valid IPv4 or IPv6 address.
  if self.validate_customer_ip_address then
    local customer_ip = ngx.req.get_headers()[X_FAPI_CUSTOMER_IP_ADDRESS]

    if customer_ip then
      -- The standard does not mention the case of having multiple IPs, but the
      -- x-fapi-customer-ip-address can contain multiple IPs, however I think it doesn't
      -- make much sense for this header to have more than one IP, so we reject the request
      -- if the header is a table.
      if not is_valid_ip(customer_ip) then
        ngx.log(ngx.WARN, "invalid x-fapi-customer-ip-address")
        return error(ngx.HTTP_FORBIDDEN, "invalid_request")
      end
    end
  end
end

function _M:header_filter()
  --- 6.2.1.11
  -- shall set the response header x-fapi-interaction-id to the value received from the corresponding FAPI client request header or to a RFC4122 UUID value if the request header was not provided to track the interaction
  local transaction_id = ngx.req.get_headers()[X_FAPI_INTERACTION_ID_HEADER]
  if not transaction_id or transaction_id == "" then
      -- Nothing found, generate one
    transaction_id = ngx.resp.get_headers()[X_FAPI_INTERACTION_ID_HEADER]
    if not transaction_id or transaction_id == "" then
      transaction_id = uuid.generate_v4()
    end
  end
  ngx.header[X_FAPI_INTERACTION_ID_HEADER] = transaction_id
end

return _M
