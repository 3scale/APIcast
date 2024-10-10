local type = type
local tostring = tostring

local ffi = require "ffi"
local base = require "resty.core.base"
local get_request = base.get_request

local C = ffi.C

local _M = {}

local NGX_OK = ngx.OK

local ngx_http_apicast_ffi_set_proxy_cert_key;
local ngx_http_apicast_ffi_set_proxy_ca_cert;
local ngx_http_apicast_ffi_set_ssl_verify

ffi.cdef([[
  int ngx_http_apicast_ffi_set_proxy_cert_key(
    ngx_http_request_t *r, void *cdata_chain, void *cdata_key);
  int ngx_http_apicast_ffi_set_proxy_ca_cert(
    ngx_http_request_t *r, void *cdata_ca);
  int ngx_http_apicast_ffi_set_ssl_verify(
    ngx_http_request_t *r, int verify, int verify_deph);
]])

ngx_http_apicast_ffi_set_proxy_cert_key = C.ngx_http_apicast_ffi_set_proxy_cert_key
ngx_http_apicast_ffi_set_proxy_ca_cert = C.ngx_http_apicast_ffi_set_proxy_ca_cert
ngx_http_apicast_ffi_set_ssl_verify = C.ngx_http_apicast_ffi_set_ssl_verify

-- Set the certs for the upstream connection. Need to receive the pointers from
-- parse_* functions.
function _M.set_upstream_cert_and_key(r, cert, key)
  if not cert or not key then
    return nil, "cert and key must not be nil"
  end

  if not r then
    return nil, "invalid request"
  end

  local ret = ngx_http_apicast_ffi_set_proxy_cert_key(r, cert, key)
  if ret ~= NGX_OK then
    return nil, "error while setting upstream client certificate and key"
  end
end

-- Set the trusted store for the upstream connection.
function _M.set_upstream_ca_cert(r, store)
  if not store then
    return nil, "trusted store must not be nil"
  end

  if not r then
    return nil, "invalid request"
  end

  local ret = ngx_http_apicast_ffi_set_proxy_ca_cert(r, store)
  if ret ~= NGX_OK then
    return nil, "error while setting upstream trusted CA store"
  end
end

-- Verify upstream connection
function _M.set_upstream_ssl_verify(r, verify, verify_deph)
  if type(verify) ~= 'boolean' then
    return nil, "verify expects a boolean but found " .. type(verify)
  end

  if type(verify_deph) ~= 'number' then
    return nil, "verify depth expects a number but found " .. type(verify)
  end

  if verify_deph < 0 then
    return nil, "verify_deph expects a non-negative interger but found" .. tostring(verify_deph)
  end

  if not r then
    return nil, "invalid request"
  end

  local val = ngx_http_apicast_ffi_set_ssl_verify(r, verify, verify_deph)
  if val ~= NGX_OK then
    return nil, "error while setting upstream verify"
  end
end

return _M
