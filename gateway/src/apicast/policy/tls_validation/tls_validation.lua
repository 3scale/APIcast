-- This is a tls_validation description.

local policy = require('apicast.policy')
local _M = policy.new('tls_validation')
local X509_STORE = require('resty.openssl.x509.store')
local X509 = require('resty.openssl.x509')
local X509_CRL = require('resty.openssl.x509.crl')
local ngx_ssl = require "ngx.ssl"

local ipairs = ipairs
local tostring = tostring

local debug = ngx.config.debug

local function init_trusted_store(store, certificates)
  for _,certificate in ipairs(certificates) do
    local cert, err = X509.new(certificate.pem_certificate) -- TODO: handle errors

    if cert then
      store:add(cert)

      if debug then
        ngx.log(ngx.DEBUG, 'adding certificate to the tls validation ', tostring(cert:subject_name()), ' SHA1: ', cert:hexdigest('SHA1'))
      end
    else
      ngx.log(ngx.WARN, 'error whitelisting certificate, err: ', err)

      if debug then
        ngx.log(ngx.DEBUG, 'certificate: ', certificate.pem_certificate)
      end
    end
  end

  return store
end

local function init_crl_list(store, crl_certificates)
  local ok, err
  local crl
  for _, certificate in ipairs(crl_certificates) do
    -- add crl to store, but skip setting the flag
    crl, err = X509_CRL.new(certificate.pem_certificate)
    if crl then
      ok, err = store:add(crl)

      if debug then
        ngx.log(ngx.DEBUG, 'adding crl certificate to the tls validation ', tostring(crl:subject_name()), ' SHA1: ', crl:hexdigest('SHA1'))
      end
    else
      ngx.log(ngx.WARN, 'failed to add crl certificate, err: ', err)

      if debug then
        ngx.log(ngx.DEBUG, 'certificate: ', certificate.pem_certificate)
      end
    end
  end
  return store
end

local new = _M.new
--- Initialize a tls_validation
-- @tparam[opt] table config Policy configuration.
function _M.new(config)
  local self = new(config)
  local store = X509_STORE.new()

  self.x509_store = init_trusted_store(store, config and config.whitelist or {})
  self.error_status = config and config.error_status or 400
  self.allow_partial_chain = config and config.allow_partial_chain
  self.revocation_type = config and config.revocation_check_type or "none"
  if self.revocation_type == "crl" then
    init_crl_list(store, config and config.revoke_list or {})
  end

  return self
end

function _M:ssl_certificate()
  -- Request client certificate
  --
  -- We don't validate the certificate during the handshake, thus set `depth` to 0 (default is 1)
  -- value here in order to save CPU cycles
  --
  -- TODO:
  -- provide ca_certs: See https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#verify_client
  -- handle verify_depth
  --
  return ngx_ssl.verify_client()
end

function _M:access()
  local client_cert = ngx.var.ssl_client_raw_cert
  if not client_cert then
    ngx.status = self.error_status
    ngx.say("No required TLS certificate was sent")
    return ngx.exit(ngx.status)
  end

  local cert, err = X509.new(client_cert)
  if not cert then
    ngx.status = self.error_status
    ngx.log(ngx.WARN, "Invalid TLS certificate, err: ", err)
    ngx.say("Invalid TLS certificate")
    return ngx.exit(ngx.status)
  end

  local store = self.x509_store

  if self.allow_partial_chain then
    store:set_flags(store.verify_flags.X509_V_FLAG_PARTIAL_CHAIN)
  end

  -- err is printed inside validate_cert method
  -- so no need capture the err here
  local chain, ok
  chain, err = store:verify(cert, nil, true)

  if not chain then
    ngx.status = self.error_status
    ngx.log(ngx.WARN, "TLS certificate validation failed, err: ", err)
    ngx.say("TLS certificate validation failed")
    return ngx.exit(ngx.status)
  end

  return true, nil
end

return _M
