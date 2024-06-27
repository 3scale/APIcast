-- This module uses lua-resty-http and properly sets it up to use http(s) proxy.

local http = require 'resty.resolver.http'
local resty_url = require 'resty.url'
local resty_env = require 'resty.env'
local url_helper = require('resty.url_helper')
local format = string.format

local _M = {

}

local function default_port(uri)
    return uri.port or resty_url.default_port(uri.scheme)
end

local function parse_request_uri(request)
    local uri = request.uri or resty_url.parse(request.url)
    request.uri = uri
    return uri
end

local function find_proxy_url(request)
    local uri = parse_request_uri(request)
    if not uri then return end

    -- request can have a local proxy defined and env variables have lower
    -- priority, if the proxy is defined in the request that will be used.
    return request.proxy_uri or _M.find(uri)
end

local function connect(request)
    request = request or { }
    local httpc = http.new()

    if request.upstream_connection_opts then
      local con_opts = request.upstream_connection_opts
      ngx.log(ngx.DEBUG, 'setting timeouts (secs), connect_timeout: ', con_opts.connect_timeout,
        ' send_timeout: ', con_opts.send_timeout, ' read_timeout: ', con_opts.read_timeout)
      -- lua-resty-http uses nginx API for lua sockets
      -- in milliseconds
      -- https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#tcpsocksettimeouts
      local connect_timeout = con_opts.connect_timeout and con_opts.connect_timeout * 1000
      local send_timeout = con_opts.send_timeout and con_opts.send_timeout * 1000
      local read_timeout = con_opts.read_timeout and con_opts.read_timeout * 1000
      httpc:set_timeouts(connect_timeout, send_timeout, read_timeout)
    end

    local proxy_uri = find_proxy_url(request)
    local uri = request.uri
    local scheme = uri.scheme
    local host = uri.host
    local port = default_port(uri)
    local skip_https_connect = request.skip_https_connect

    -- set ssl_verify: lua-resty-http set ssl_verify to true by default if scheme is https, whereas
    -- openresty treat nil as false, so we need to explicitly set ssl_verify to false if nil
    local ssl_verify = request.options and request.options.ssl and request.options.ssl.verify or false

    -- We need to set proxy_opts to an empty table here otherwise, lua-resty-http will fallback
    -- to the global proxy options
    local options = {
      scheme = scheme,
      host = host,
      port = port,
      proxy_opts = {}
    }
    if scheme == 'https' then
        options.ssl_server_name = host
        options.ssl_verify = ssl_verify
    end

    -- Connect via proxy
    if proxy_uri then
        if proxy_uri.scheme ~= 'http' then
            return nil, 'proxy connection supports only http'
        else
            proxy_uri.port = default_port(proxy_uri)
        end

        local proxy_url = format("%s://%s:%s", proxy_uri.scheme, proxy_uri.host, proxy_uri.port)
        local proxy_auth = request.proxy_auth

        if scheme == 'http' then
            -- Used by http_ng module to send request to 3scale backend through proxy.

            -- http proxy needs absolute URL as the request path, lua-resty-http 1.17.1 will
            -- construct a path_prefix based on host and port so we only set request path here
            --
            -- https://github.com/ledgetech/lua-resty-http/blob/master/lib/resty/http_connect.lua#L99
            request.path = uri.path or '/'
            options.proxy_opts = {
                http_proxy = proxy_url,
                http_proxy_authorization = proxy_auth
            }
        elseif scheme == 'https' and skip_https_connect then
            options.scheme = proxy_uri.scheme
            options.host = proxy_uri.host
            options.port = proxy_uri.port
            options.pool = format('%s:%s:%s:%s', proxy_uri.host, proxy_uri.port, host, port)
            local custom_uri = { scheme = uri.scheme, host = uri.host, port = uri.port, path = request.path }
            request.path = url_helper.absolute_url(custom_uri)

            local ok, err = httpc:connect(options)
            if not ok then return nil, err end

            ngx.log(ngx.DEBUG, 'connection to ', proxy_uri.host, ':', proxy_uri.port, ' established',
                ', pool: ', httpc.pool, ' reused times: ', httpc:get_reused_times())

            ngx.log(ngx.DEBUG, 'targeting server ', host, ':', port)

            local ok, err = httpc:ssl_handshake(nil, host, request.ssl_verify)
            if not ok then return nil, err end

            return httpc
        elseif scheme == 'https' then
            options.proxy_opts = {
                https_proxy = proxy_url,
                https_proxy_authorization = proxy_auth
            }
        else
            return nil, 'invalid scheme'
        end

        -- TLS tunnel is verified only once, so we need to reuse connections only for the same Host header
        local ok, err = httpc:connect(options)
        if not ok then return nil, err end

        ngx.log(ngx.DEBUG, 'connection to ', proxy_uri.host, ':', proxy_uri.port, ' established',
            ', pool: ', httpc.pool, ' reused times: ', httpc:get_reused_times())
        ngx.log(ngx.DEBUG, 'targeting server ', host, ':', port)
    else
        -- Connect direct
        -- Mostly used by http_ng module to connect 3scale backend module.
        local ok, err = httpc:connect(options)
        if not ok then return nil, err end

        ngx.log(ngx.DEBUG, 'connection to ', httpc.host, ':', httpc.port, ' established',
            ', pool: ', httpc.pool, ' reused times: ', httpc:get_reused_times())
    end


    return httpc
end

function _M.env()
    local all_proxy = resty_env.value('all_proxy') or resty_env.value('ALL_PROXY')

    return {
        http_proxy = resty_env.value('http_proxy') or resty_env.value('HTTP_PROXY') or all_proxy,
        https_proxy = resty_env.value('https_proxy') or resty_env.value('HTTPS_PROXY') or all_proxy,
        no_proxy = resty_env.value('no_proxy') or resty_env.value('NO_PROXY'),
    }
end

local options

function _M.options() return options end

function _M.active(request)
    return not not find_proxy_url(request)
end

function _M.find(uri)
    local proxy_url = http:get_proxy_uri(uri.scheme, uri.host)

    if proxy_url then
        return resty_url.parse(proxy_url)
    else
        return nil, 'no_proxy'
    end
end

function _M:reset(opts)
    options = opts or self.env()

    http:set_proxy_options(options)

    return self
end

_M.new = connect

return _M:reset()
