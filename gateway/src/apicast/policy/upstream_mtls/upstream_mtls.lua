-- This policy enables MTLS with the upstream API endpoint

local ssl = require('ngx.ssl')
local ffi = require "ffi"
local base = require "resty.core.base"
local data_url = require('resty.data_url')
local util = require 'apicast.util'
local tls = require 'resty.tls'

local C = ffi.C
local get_request = base.get_request
local pairs = pairs

local X509_STORE = require('resty.openssl.x509.store')
local X509 = require('resty.openssl.x509')

ffi.cdef([[
  int ngx_http_apicast_ffi_set_proxy_cert_key(
    ngx_http_request_t *r, void *cdata_chain, void *cdata_key);
  int ngx_http_apicast_ffi_set_proxy_ca_cert(
    ngx_http_request_t *r, void *cdata_ca);
  int ngx_http_apicast_ffi_set_ssl_verify(
    ngx_http_request_t *r, int verify, int verify_deph);
]])


local policy = require('apicast.policy')
local _M = policy.new('mtls', "builtin")

local path_type = "path"
local embedded_type = "embedded"

local new = _M.new

local function get_cert(value, value_type)

  if value_type == path_type then
    ngx.log(ngx.DEBUG, "reading path:", value)
    return util.read_file(value)
  end

  if value_type == embedded_type then
    local parsed_data, err = data_url.parse(value)
    if err then
      ngx.log(ngx.ERR, "Cannot parse certificate content: ", err)
      return nil
    end
    return parsed_data.data
  end
end

local function read_certificate(value, value_type)
  local data = get_cert(value, value_type)
  if data == nil then
    ngx.log(ngx.ERR, "Certificate value is invalid")
    return
  end
  return ssl.parse_pem_cert(data)
end

local function read_certificate_key(value, value_type)
  local data = get_cert(value, value_type)

  if data == nil then
    ngx.log(ngx.ERR, "Certificate key value is invalid")
    return
  end

  return ssl.parse_pem_priv_key(data)
end

local function read_ca_certificates(ca_certificates)
  local valid = false
  local store = X509_STORE.new()
  for _,certificate in pairs(ca_certificates) do
    local cert, err = X509.parse_pem_cert(certificate)
    if cert then
      valid = true
      store:add_cert(cert)
    else
      ngx.log(ngx.INFO, "cannot load certificate, err: ", err)
    end
  end

  if valid then
    return store.store
  end
end

function _M.new(config)
  local self = new(config)
  if config == nil then
    config = {}
  end

  self.cert = read_certificate(
    config.certificate,
    config.certificate_type or path_type)
  self.cert_key = read_certificate_key(
    config.certificate_key,
    config.certificate_key_type or path_type)
  self.ca_store = read_ca_certificates(config.ca_certificates or {})
  self.verify = config.verify

  return self
end

function _M:rewrite(context)
  context.upstream_certificate = self.cert
  context.upstream_key = self.cert_key
  context.upstream_verify = self.verify
  context.upstream_ca_store = self.ca_store
end

return _M
