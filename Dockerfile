FROM registry.access.redhat.com/ubi8:8.5 AS opentelemetry-builder

ARG OPENRESTY_RPM_VERSION="1.19.3"

RUN sed -i s/enabled=./enabled=0/g /etc/yum/pluginconf.d/subscription-manager.conf

RUN yum install -y pcre-devel zlib-devel libcurl-devel cmake gcc gcc-c++ git

WORKDIR /tmp

RUN git clone --shallow-submodules --depth 1 --recurse-submodules -b v1.36.4 \
  https://github.com/grpc/grpc \
  && cd grpc \
  && mkdir -p cmake/build \
  && cd cmake/build \
  && cmake \
    -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX=/install \
    -DCMAKE_BUILD_TYPE=Release \
    -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF \
    ../.. \
  && make -j8 VERBOSE=1 \
  && make install

RUN git clone --shallow-submodules --depth 1 --recurse-submodules -b v1.6.1 \
  https://github.com/open-telemetry/opentelemetry-cpp.git \
  && cd opentelemetry-cpp \
  && mkdir build \
  && cd build \
  && cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/install \
    -DCMAKE_PREFIX_PATH=/install \
    -DWITH_OTLP=ON \
    -DWITH_OTLP_GRPC=ON \
    -DWITH_OTLP_HTTP=OFF \
    -DBUILD_TESTING=OFF \
    -DWITH_EXAMPLES=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    .. \
  && make -j8 VERBOSE=1 \
  && make install

ADD https://github.com/open-telemetry/opentelemetry-cpp-contrib/archive/refs/tags/webserver/v1.0.1.tar.gz ./

RUN tar -xzvf v1.0.1.tar.gz && rm v1.0.1.tar.gz

RUN mkdir -p otel-nginx/build && mkdir -p otel-nginx/src
RUN cp -r /tmp/opentelemetry-cpp-contrib-webserver-v1.0.1/instrumentation/nginx/src otel-nginx/
RUN cp /tmp/opentelemetry-cpp-contrib-webserver-v1.0.1/instrumentation/nginx/CMakeLists.txt /tmp/opentelemetry-cpp-contrib-webserver-v1.0.1/instrumentation/nginx/nginx.cmake otel-nginx/
RUN cd otel-nginx/build \
  && cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH=/install \
    -DCMAKE_INSTALL_PREFIX=/usr/share/nginx/modules \
    -DNGINX_VERSION=1.19.3 \
    .. \
  && make -j8 VERBOSE=1 \
  && make install

FROM registry.access.redhat.com/ubi8:8.5

ARG OPENRESTY_RPM_VERSION="1.19.3"

LABEL summary="The 3scale API gateway (APIcast) is an OpenResty application, which consists of two parts: NGINX configuration and Lua files." \
      description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.display-name="3scale API gateway (APIcast)" \
      io.openshift.expose-services="8080:apicast" \
      io.openshift.tags="integration, nginx, lua, openresty, api, gateway, 3scale, rhamp" \
      maintainer="3scale-engineering@redhat.com"

WORKDIR /tmp

ENV AUTO_UPDATE_INTERVAL=0 \
    # The $HOME is not set by default, but some applications needs this variable
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    PLATFORM="el8"

RUN sed -i s/enabled=./enabled=0/g /etc/yum/pluginconf.d/subscription-manager.conf

RUN dnf install -y 'dnf-command(config-manager)'

RUN yum config-manager --add-repo http://packages.dev.3sca.net/dev_packages_3sca_net.repo

RUN PKGS="perl-interpreter-5.26.3 libyaml-devel-0.1.7 m4 openssl-devel git gcc make curl openresty-resty-${OPENRESTY_RPM_VERSION} luarocks-2.3.0 opentracing-cpp-devel-1.3.0 libopentracing-cpp1-1.3.0 jaegertracing-cpp-client openresty-opentracing-${OPENRESTY_RPM_VERSION}" && \
    mkdir -p "$HOME" && \
    yum -y --setopt=tsflags=nodocs install $PKGS && \
    rpm -V $PKGS && \
    yum clean all -y

COPY site_config.lua /usr/share/lua/5.1/luarocks/site_config.lua
COPY config-*.lua /usr/local/openresty/config-5.1.lua

ENV PATH="./lua_modules/bin:/usr/local/openresty/luajit/bin/:${PATH}" \
    LUA_PATH="./lua_modules/share/lua/5.1/?.lua;./lua_modules/share/lua/5.1/?/init.lua;/usr/lib64/lua/5.1/?.lua;/usr/share/lua/5.1/?.lua" \
    LUA_CPATH="./lua_modules/lib/lua/5.1/?.so;;" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"

COPY --from=opentelemetry-builder /usr/share/nginx/modules/otel_ngx_module.so /usr/local/openresty/nginx/modules

RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/pintsized/lua-resty-http-0.15-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/kikito/router-2.1-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/kikito/inspect-3.1.1-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/cdbattags/lua-resty-jwt-0.2.0-0.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-url-0.3.5-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-env-0.4.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/liquid-0.2.0-2.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/tieske/date-2.2-2.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/tieske/penlight-1.7.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/mpeterv/argparse-0.6.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-execvp-0.1.1-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/luafilesystem-ffi-0.2.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/3scale/lua-resty-jit-uuid-0.0.7-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/knyar/nginx-lua-prometheus-0.20181120-2.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/hamish/lua-resty-iputils-0.3.0-1.src.rock
RUN luarocks install --deps-mode=none --tree /usr/local https://luarocks.org/manifests/golgote/net-url-0.9-1.src.rock

RUN yum -y remove libyaml-devel m4 openssl-devel git gcc luarocks && \
    rm -rf /var/cache/yum && yum clean all -y && \
    rm -rf ./*

COPY gateway/. /opt/app-root/src/

RUN mkdir -p /opt/app-root/src/logs && \
    useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin -c "Default Application User" default && \
    rm -r /usr/local/openresty/nginx/logs && \
    ln -s /opt/app-root/src/logs /usr/local/openresty/nginx/logs && \
    ln -s /dev/stdout /opt/app-root/src/logs/access.log && \
    ln -s /dev/stderr /opt/app-root/src/logs/error.log && \
    mkdir -p /usr/local/share/lua/ && \
    chmod g+w /usr/local/share/lua/ && \
    mkdir -p /usr/local/openresty/nginx/{client_body_temp,fastcgi_temp,proxy_temp,scgi_temp,uwsgi_temp} && \
    chown -R 1001:0 /opt/app-root /usr/local/share/lua/ /usr/local/openresty/nginx/{client_body_temp,fastcgi_temp,proxy_temp,scgi_temp,uwsgi_temp}

RUN ln --verbose --symbolic /opt/app-root/src/bin /opt/app-root/bin && \
    ln --verbose --symbolic /opt/app-root/src/http.d /opt/app-root/http.d && \
    ln --verbose --symbolic --force /etc/ssl/certs/ca-bundle.crt "/opt/app-root/src/conf" && \
    chmod --verbose g+w "${HOME}" "${HOME}"/* "${HOME}/http.d" && \
    chown -R 1001:0 /opt/app-root

RUN ln --verbose --symbolic /opt/app-root/src /opt/app-root/app && \
    ln --verbose --symbolic /opt/app-root/bin /opt/app-root/scripts

WORKDIR /opt/app-root/app

USER 1001

ENV LUA_CPATH "./?.so;/usr/lib64/lua/5.1/?.so;/usr/lib64/lua/5.1/loadall.so;/usr/local/lib64/lua/5.1/?.so"
ENV LUA_PATH "/usr/lib64/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/*/?.lua;"

WORKDIR /opt/app-root
ENTRYPOINT ["container-entrypoint"]
CMD ["scripts/run"]
