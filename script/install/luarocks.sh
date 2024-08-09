set -x -e

LUAROCKS_VER="3.8.0"
OPENRESTY_PREFIX="/usr/local/openresty"
WITH_LUA_OPT="--with-lua=${OPENRESTY_PREFIX}/luajit"
APP_ROOT=/opt/app-root

export PATH=$PATH:/usr/local/bin

wget -q https://github.com/luarocks/luarocks/archive/v"$LUAROCKS_VER".tar.gz
tar -xf v"$LUAROCKS_VER".tar.gz
cd luarocks-"$LUAROCKS_VER" || exit
./configure $WITH_LUA_OPT

make && make install
cd ..
rm -rf luarocks-"$LUAROCKS_VER"
rm -f v"$LUAROCKS_VER".tar.gz

cp ${APP_ROOT}/site_config.lua /usr/local/share/lua/5.1/luarocks/site_config.lua
cp ${APP_ROOT}/config-*.lua /usr/local/openresty/config-5.1.lua

luarocks install luaossl 20200709 --tree ${APP_ROOT}/lua_modules CFLAGS="-O2 -fPIC -DHAVE_EVP_KDF_CTX=1"
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/pintsized/lua-resty-http-0.17.1-0.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/kikito/router-2.1-0.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/kikito/inspect-3.1.1-0.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/cdbattags/lua-resty-jwt-0.2.0-0.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-url-0.3.5-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-env-0.4.0-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/liquid-0.2.0-2.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/tieske/date-2.2-2.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/tieske/penlight-1.13.1-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/mpeterv/argparse-0.6.0-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-execvp-0.1.1-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/hisham/luafilesystem-1.8.0-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-jit-uuid-0.0.7-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/knyar/nginx-lua-prometheus-0.20181120-2.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/hamish/lua-resty-iputils-0.3.0-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/golgote/net-url-0.9-1.src.rock
luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/membphis/lua-resty-ipmatcher-0.6.1-0.src.rock
