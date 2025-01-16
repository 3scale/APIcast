set -x -e

OPENRESTY_YUM_REPO="https://openresty.org/package/centos/openresty.repo"
THREESCALE_YUM_REPO="http://packages.dev.3sca.net/dev_packages_3sca_net.repo"
OPENRESTY_RPM_VERSION="1.21.4-1.el8"
JAEGERTRACING_CPP_CLIENT_RPM_VERSION="0.3.1-13.el8"

APP_ROOT=/opt/app-root
HOME=/opt/app-root/src
PATH=/opt/app-root/src/bin:/opt/app-root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

## add openresty and 3scale rpm repo
yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
yum-config-manager --add-repo http://packages.dev.3sca.net/dev_packages_3sca_net.repo

yum -y install \
    openresty-${OPENRESTY_RPM_VERSION} \
    openresty-resty-${OPENRESTY_RPM_VERSION} \
    openresty-debuginfo-${OPENRESTY_RPM_VERSION} \
    openresty-debugsource-${OPENRESTY_RPM_VERSION} \
    openresty-opentelemetry-${OPENRESTY_RPM_VERSION}

export PATH="./lua_modules/bin:/usr/local/openresty/luajit/bin/:${PATH}"
export LUA_PATH="./lua_modules/share/lua/5.1/?.lua;./lua_modules/share/lua/5.1/?/init.lua;/usr/lib64/lua/5.1/?.lua;/usr/share/lua/5.1/?.lua;/opt/app-root/lua_modules/share/lua/5.1/?.lua;/opt/app-root/lua_modules/share/lua/5.1/?/?.lua"
export LUA_CPATH="./lua_modules/lib/lua/5.1/?.so;/opt/app-root/lua_modules/lib64/lua/5.1/?.so;/opt/app-root/lua_modules/lib64/lua/5.1/?/?.so;;"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"

ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log
ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log
mkdir -p /usr/local/openresty/nginx/client_body_temp/
chmod 777 /usr/local/openresty/nginx/client_body_temp/
