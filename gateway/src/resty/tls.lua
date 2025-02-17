local base = require "resty.core.base"

local type = type
local tostring = tostring

local get_request = base.get_request
local get_size_ptr = base.get_size_ptr
local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C

local _M = {}

local NGX_OK = ngx.OK
local NGX_ERROR = ngx.ERROR
local NGX_DECLINED = ngx.DECLINED

local ngx_http_apicast_ffi_get_full_client_certificate_chain;
local ngx_http_apicast_ffi_set_proxy_cert_key;
local ngx_http_apicast_ffi_set_proxy_ca_cert;
local ngx_http_apicast_ffi_set_ssl_verify

local value_ptr = ffi_new("unsigned char *[1]")

ffi.cdef([[
  int ngx_http_apicast_ffi_get_full_client_certificate_chain(
    ngx_http_request_t *r, char **value, size_t *value_len);
  int ngx_http_apicast_ffi_set_proxy_cert_key(
    ngx_http_request_t *r, void *cdata_chain, void *cdata_key);
  int ngx_http_apicast_ffi_set_proxy_ca_cert(
    ngx_http_request_t *r, void *cdata_ca);
  int ngx_http_apicast_ffi_set_ssl_verify(
    ngx_http_request_t *r, int verify, int verify_deph);
]])

ngx_http_apicast_ffi_get_full_client_certificate_chain = C.ngx_http_apicast_ffi_get_full_client_certificate_chain
ngx_http_apicast_ffi_set_proxy_cert_key = C.ngx_http_apicast_ffi_set_proxy_cert_key
ngx_http_apicast_ffi_set_proxy_ca_cert = C.ngx_http_apicast_ffi_set_proxy_ca_cert
ngx_http_apicast_ffi_set_ssl_verify = C.ngx_http_apicast_ffi_set_ssl_verify

-- Set the certs for the upstream connection. Need to receive the pointers from
-- parse_* functions.
function _M.set_upstream_cert_and_key(cert, key)
  local r = get_request()
  if not r then
      error("no request found")
  end

  if not cert or not key then
    return nil, "cert and key must not be nil"
  end

  local ret = ngx_http_apicast_ffi_set_proxy_cert_key(r, cert, key)
  if ret ~= NGX_OK then
    return nil, "error while setting upstream client certificate and key"
  end
end

-- Set the trusted store for the upstream connection.
function _M.set_upstream_ca_cert(store)
  local r = get_request()
  if not r then
      error("no request found")
  end

  if not store then
    return nil, "trusted store must not be nil"
  end

  local ret = ngx_http_apicast_ffi_set_proxy_ca_cert(r, store)
  if ret ~= NGX_OK then
    return nil, "error while setting upstream trusted CA store"
  end
end

-- Verify upstream connection
function _M.set_upstream_ssl_verify(verify, verify_deph)
  local r = get_request()
  if not r then
      error("no request found")
  end

  if type(verify) ~= 'boolean' then
    return nil, "verify expects a boolean but found " .. type(verify)
  end

  if type(verify_deph) ~= 'number' then
    return nil, "verify depth expects a number but found " .. type(verify)
  end

  if verify_deph < 0 then
    return nil, "verify_deph expects a non-negative interger but found" .. tostring(verify_deph)
  end

  local val = ngx_http_apicast_ffi_set_ssl_verify(r, verify, verify_deph)
  if val ~= NGX_OK then
    return nil, "error while setting upstream verify"
  end
end

-- Retrieve the full client certificate chain
function _M.get_full_client_certificate_chain()
  local r = get_request()
  if not r then
      error("no request found")
  end

  local size_ptr = get_size_ptr()

  local rc = ngx_http_apicast_ffi_get_full_client_certificate_chain(r, value_ptr, size_ptr)

  if rc == NGX_OK then
      return ffi_str(value_ptr[0], size_ptr[0])
  end

  if rc == NGX_ERROR then
      return nil, "error while obtaining client certificate chain"
  end


  if rc == NGX_DECLINED then
      return nil
  end
end

return _M
