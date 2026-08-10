local nginx_metrics = require('apicast.policy.nginx_metrics.nginx_metrics')

describe('nginx_metrics policy', function()
  describe('.log', function()
    local upstream_metrics

    before_each(function()
      upstream_metrics = require('apicast.metrics.upstream')
      stub(upstream_metrics, 'report')

      local metrics_updater = require('apicast.metrics.updater')
      stub(metrics_updater, 'inc')

      ngx.status = 200
    end)

    it('uses ngx.var upstream values when present', function()
      ngx.var = { upstream_status = '200', upstream_response_time = '0.5' }
      ngx.ctx = { proxy_upstream_status = 502, proxy_upstream_response_time = 1.2 }

      nginx_metrics.log(nil, {})

      assert.stub(upstream_metrics.report).was_called_with('200', '0.5', { id = "", system_name = "" })
    end)

    it('falls back to ngx.ctx values set by the http_proxy module when ngx.var ones are missing', function()
      ngx.var = { upstream_status = nil, upstream_response_time = nil }
      ngx.ctx = { proxy_upstream_status = 200, proxy_upstream_response_time = 0.75 }

      nginx_metrics.log(nil, {})

      assert.stub(upstream_metrics.report).was_called_with(200, 0.75, { id = "", system_name = "" })
    end)

    it('reports nil when neither ngx.var nor ngx.ctx have upstream values', function()
      ngx.var = { upstream_status = nil, upstream_response_time = nil }
      ngx.ctx = {}

      nginx_metrics.log(nil, {})

      assert.stub(upstream_metrics.report).was_called_with(nil, nil, { id = "", system_name = "" })
    end)
  end)
end)
