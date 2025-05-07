local pl_path = require 'pl.path'

local _M = {}

do
  -- Possible certificate files; stop after finding one.
  -- copied from https://github.com/golang/go/blob/master/src/crypto/x509/root_linux.go#L9
  local trusted_cert_files = {
    "/etc/ssl/certs/ca-certificates.crt",                -- Debian/Ubuntu/Gentoo etc.
    "/etc/pki/tls/certs/ca-bundle.crt",                  -- Fedora/RHEL 6
    "/etc/ssl/ca-bundle.pem",                            -- OpenSUSE
    "/etc/pki/tls/cacert.pem",                           -- OpenELEC
    "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem", -- CentOS/RHEL 7
    "/etc/ssl/cert.pem",                                 -- Alpine Linux
  }

  -- Load CA certs in order, the first one found will be used.
  --   from context
  --   from default system location
  --   local APIcast ca-bundle (for backward compatible)
  --
  function _M.get_system_trusted_certs_filepath()
    for _, path in ipairs(trusted_cert_files) do
      if pl_path.exists(path) then
        return path
      end
    end

    return nil
  end
end

return _M
