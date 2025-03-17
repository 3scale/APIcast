local system = require "resty.system"
local pl_path = require "pl.path"

describe("resty.system", function()
  describe("get_system_trusted_certs_filepath", function ()
    local old_exists = pl_path.exists
    after_each(function()
      pl_path.exists = old_exists
    end)

    it("retrieves the default filepath", function()
      local tests = {
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
        "/etc/ssl/ca-bundle.pem",
        "/etc/pki/tls/cacert.pem",
        "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",
        "/etc/ssl/cert.pem",
      }
      for _, test_path in pairs(tests) do
        pl_path.exists = function(path)
          return path == test_path
        end
        assert.same(test_path, system.get_system_trusted_certs_filepath())
      end
    end)

    it("return nil if nothing found", function()
      pl_path.exists = function(path)
        return false
      end

      local ok = system.get_system_trusted_certs_filepath()
      assert.is_nil(ok)
    end)
  end)
end)
