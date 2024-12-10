FROM registry.access.redhat.com/ubi8/ubi:8.10-1132.1731461736 AS rpm-builder

# Install rpm-build and dependencies, move sources and spec file to their respective directories, build the  RPMs and install them
RUN yum install -y rpm-build cmake3 gcc-c++ yum-utils

ENV RPMBUILD_ROOT="/root/rpmbuild"

RUN mkdir -p ${RPMBUILD_ROOT}/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
RUN echo "%_topdir /root/rpmbuild" > "/root/.rpmmacros"

ENV RPMBUILD_ROOT="/root/rpmbuild"

WORKDIR ${RPMBUILD_ROOT}

FROM rpm-builder as openresty-pcre

COPY dependencies/rpm-specs/openresty-pcre/openresty-pcre.spec ${RPMBUILD_ROOT}/SPECS/openresty-pcre.spec
RUN yum-builddep --assumeyes SPECS/openresty-pcre.spec

COPY dependencies/rpm-specs/openresty-pcre/sources/pcre-8.44 ${RPMBUILD_ROOT}/SOURCES/pcre-8.44
RUN rpmbuild -ba SPECS/openresty-pcre.spec


FROM rpm-builder as openresty-zlib

COPY dependencies/rpm-specs/openresty-zlib/openresty-zlib.spec ${RPMBUILD_ROOT}/SPECS/openresty-zlib.spec
RUN yum-builddep --assumeyes SPECS/openresty-zlib.spec

COPY dependencies/git/zlib ${RPMBUILD_ROOT}/SOURCES/zlib-1.2.11
RUN rpmbuild -ba SPECS/openresty-zlib.spec


FROM rpm-builder as opentracing-cpp

COPY dependencies/rpm-specs/opentracing-cpp/opentracing-cpp.spec ${RPMBUILD_ROOT}/SPECS/opentracing-cpp.spec
RUN yum-builddep --assumeyes SPECS/opentracing-cpp.spec

COPY dependencies/git/opentracing-cpp ${RPMBUILD_ROOT}/SOURCES/opentracing-cpp-1.3.0
RUN rpmbuild -ba SPECS/opentracing-cpp.spec


FROM rpm-builder as openresty

# Copy *.rpm files from earlier stages to /tmp/ so we can install RPMs
COPY --from=openresty-pcre /root/rpmbuild/RPMS /tmp/openresty-pcre/RPMS
COPY --from=openresty-zlib /root/rpmbuild/RPMS /tmp/openresty-zlib/RPMS
COPY --from=opentracing-cpp /root/rpmbuild/RPMS /tmp/opentracing-cpp/RPMS

# TODO: fix this later - uncomment for local build
#COPY dependencies/rpm-specs/tmp/annobin-annocheck-10.67-3.el8.x86_64.rpm /tmp/annobin-annocheck-10.67-3.el8.x86_64.rpm
#RUN yum localinstall --assumeyes \
#    /tmp/annobin-annocheck-10.67-3.el8.x86_64.rpm
RUN yum install --assumeyes gcc-toolset-12-annobin-annocheck
RUN yum localinstall --assumeyes \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-devel-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-1.2.11-122.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-devel-1.2.11-122.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/libopentracing-cpp1-1.3.0-132.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/opentracing-cpp-devel-1.3.0-132.el8.`arch`.rpm

COPY dependencies/rpm-specs/openresty/openresty.spec ${RPMBUILD_ROOT}/SPECS/openresty.spec
RUN yum-builddep --assumeyes SPECS/openresty.spec

COPY dependencies/git/array-var-nginx-module ${RPMBUILD_ROOT}/SOURCES/array-var-nginx-module-v0.05
COPY dependencies/git/drizzle-nginx-module ${RPMBUILD_ROOT}/SOURCES/drizzle-nginx-module-v0.1.11
COPY dependencies/git/echo-nginx-module ${RPMBUILD_ROOT}/SOURCES/echo-nginx-module-v0.62
COPY dependencies/git/encrypted-session-nginx-module ${RPMBUILD_ROOT}/SOURCES/encrypted-session-nginx-module-v0.08
COPY dependencies/git/form-input-nginx-module ${RPMBUILD_ROOT}/SOURCES/form-input-nginx-module-v0.12
COPY dependencies/git/headers-more-nginx-module ${RPMBUILD_ROOT}/SOURCES/headers-more-nginx-module-v0.33
COPY dependencies/git/iconv-nginx-module ${RPMBUILD_ROOT}/SOURCES/iconv-nginx-module-v0.14
COPY dependencies/git/lua-cjson ${RPMBUILD_ROOT}/SOURCES/lua-cjson-2.1.0.8
COPY dependencies/git/luajit2 ${RPMBUILD_ROOT}/SOURCES/luajit2-v2.1-20201027-product-zfixes
COPY dependencies/git/lua-nginx-module ${RPMBUILD_ROOT}/SOURCES/lua-nginx-module-v0.10.19
COPY dependencies/git/lua-rds-parser ${RPMBUILD_ROOT}/SOURCES/lua-rds-parser-v0.06
COPY dependencies/git/lua-redis-parser ${RPMBUILD_ROOT}/SOURCES/lua-redis-parser-v0.13
COPY dependencies/git/lua-resty-core ${RPMBUILD_ROOT}/SOURCES/lua-resty-core-v0.1.21
COPY dependencies/git/lua-resty-dns ${RPMBUILD_ROOT}/SOURCES/lua-resty-dns-v0.21
COPY dependencies/git/lua-resty-limit-traffic ${RPMBUILD_ROOT}/SOURCES/lua-resty-limit-traffic-v0.07
COPY dependencies/git/lua-resty-lock ${RPMBUILD_ROOT}/SOURCES/lua-resty-lock-v0.08
COPY dependencies/git/lua-resty-lrucache ${RPMBUILD_ROOT}/SOURCES/lua-resty-lrucache-v0.10
COPY dependencies/git/lua-resty-memcached ${RPMBUILD_ROOT}/SOURCES/lua-resty-memcached-v0.15
COPY dependencies/git/lua-resty-mysql ${RPMBUILD_ROOT}/SOURCES/lua-resty-mysql-v0.23
COPY dependencies/git/lua-resty-redis ${RPMBUILD_ROOT}/SOURCES/lua-resty-redis-v0.29
COPY dependencies/git/lua-resty-shell ${RPMBUILD_ROOT}/SOURCES/lua-resty-shell-v0.03
COPY dependencies/git/lua-resty-signal ${RPMBUILD_ROOT}/SOURCES/lua-resty-signal-v0.02
COPY dependencies/git/lua-resty-string ${RPMBUILD_ROOT}/SOURCES/lua-resty-string-v0.12
COPY dependencies/git/lua-resty-upload ${RPMBUILD_ROOT}/SOURCES/lua-resty-upload-v0.10
COPY dependencies/git/lua-resty-upstream-healthcheck ${RPMBUILD_ROOT}/SOURCES/lua-resty-upstream-healthcheck-v0.06
COPY dependencies/git/lua-resty-websocket ${RPMBUILD_ROOT}/SOURCES/lua-resty-websocket-v0.08
COPY dependencies/git/lua-tablepool ${RPMBUILD_ROOT}/SOURCES/lua-tablepool-v0.01
COPY dependencies/git/lua-upstream-nginx-module ${RPMBUILD_ROOT}/SOURCES/lua-upstream-nginx-module-v0.07
COPY dependencies/git/memc-nginx-module ${RPMBUILD_ROOT}/SOURCES/memc-nginx-module-v0.19
COPY dependencies/git/nginx ${RPMBUILD_ROOT}/SOURCES/nginx-release-1.19.3-product-4
COPY dependencies/git/ngx_coolkit ${RPMBUILD_ROOT}/SOURCES/ngx_coolkit-0.2
COPY dependencies/git/ngx_devel_kit ${RPMBUILD_ROOT}/SOURCES/ngx_devel_kit-v0.3.1
COPY dependencies/git/ngx_http_redis ${RPMBUILD_ROOT}/SOURCES/ngx_http_redis-0.3.7
COPY dependencies/git/ngx_postgres ${RPMBUILD_ROOT}/SOURCES/ngx_postgres-1.0
COPY dependencies/git/opm ${RPMBUILD_ROOT}/SOURCES/opm-v0.0.5
COPY dependencies/git/rds-csv-nginx-module ${RPMBUILD_ROOT}/SOURCES/rds-csv-nginx-module-v0.09
COPY dependencies/git/rds-json-nginx-module ${RPMBUILD_ROOT}/SOURCES/rds-json-nginx-module-v0.15
COPY dependencies/git/redis2-nginx-module ${RPMBUILD_ROOT}/SOURCES/redis2-nginx-module-v0.15
COPY dependencies/git/resty-cli ${RPMBUILD_ROOT}/SOURCES/resty-cli-v0.27
COPY dependencies/git/set-misc-nginx-module ${RPMBUILD_ROOT}/SOURCES/set-misc-nginx-module-v0.32
COPY dependencies/git/srcache-nginx-module ${RPMBUILD_ROOT}/SOURCES/srcache-nginx-module-v0.32
COPY dependencies/git/stream-lua-nginx-module ${RPMBUILD_ROOT}/SOURCES/stream-lua-nginx-module-v0.0.9
COPY dependencies/git/xss-nginx-module ${RPMBUILD_ROOT}/SOURCES/xss-nginx-module-v0.06
COPY dependencies/git/nginx-opentracing ${RPMBUILD_ROOT}/SOURCES/nginx-opentracing-v0.3.0
COPY dependencies/git/apicast-nginx-module ${RPMBUILD_ROOT}/SOURCES/apicast-nginx-module-v0.4
COPY dependencies/git/grpc ${RPMBUILD_ROOT}/SOURCES/grpc-v1.49.2
COPY dependencies/git/opentelemetry-proto ${RPMBUILD_ROOT}/SOURCES/opentelemetry-proto-v0.19.0
COPY dependencies/git/opentelemetry-cpp ${RPMBUILD_ROOT}/SOURCES/opentelemetry-cpp-v1.8.1
COPY dependencies/git/opentelemetry-cpp-contrib ${RPMBUILD_ROOT}/SOURCES/opentelemetry-cpp-contrib-1ec94c82095bab61f06c7393b6f3272469d285af
COPY dependencies/git/openresty ${RPMBUILD_ROOT}/SOURCES/openresty-189070e331150d40d360b77699ccd8e38bc1ae05

WORKDIR ${RPMBUILD_ROOT}/SOURCES

RUN directories=($(find . -maxdepth 1 -type d -printf '%f\n')); \
    for dir in "${directories[@]}"; do \
      if [[ $dir != "." ]]; then \
        tar --create --gzip --file="${dir##*/}.tar.gz" "$dir" ; \
      fi \
    done

RUN ls -alh

WORKDIR ${RPMBUILD_ROOT}

RUN rpmbuild -ba SPECS/openresty.spec

FROM rpm-builder as luarocks

COPY dependencies/rpm-specs/luarocks/luarocks.spec ${RPMBUILD_ROOT}/SPECS/luarocks.spec

# install package dependencies
ARG OPENRESTY_RPM_VERSION="1.19.3-123.el8"
COPY --from=openresty-pcre /root/rpmbuild/RPMS /tmp/openresty-pcre/RPMS
COPY --from=openresty-zlib /root/rpmbuild/RPMS /tmp/openresty-zlib/RPMS
COPY --from=opentracing-cpp /root/rpmbuild/RPMS /tmp/opentracing-cpp/RPMS
COPY --from=openresty /root/rpmbuild/RPMS /tmp/openresty/RPMS
RUN yum localinstall --assumeyes \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-devel-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-1.2.11-122.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-devel-1.2.11-122.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/libopentracing-cpp1-1.3.0-132.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/opentracing-cpp-devel-1.3.0-132.el8.`arch`.rpm \
    /tmp/openresty/RPMS/noarch/openresty-resty-${OPENRESTY_RPM_VERSION}.noarch.rpm \
    /tmp/openresty/RPMS/noarch/openresty-opm-${OPENRESTY_RPM_VERSION}.noarch.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-opentelemetry-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-opentracing-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-${OPENRESTY_RPM_VERSION}.`arch`.rpm

RUN yum-builddep --assumeyes SPECS/luarocks.spec

ARG LUAROCKS_VERSION="2.3.0-105.el8"

COPY dependencies/git/luarocks ${RPMBUILD_ROOT}/SOURCES/luarocks-${LUAROCKS_VERSION}
WORKDIR ${RPMBUILD_ROOT}/SOURCES
RUN tar --create --gzip --file="luarocks-${LUAROCKS_VERSION}.tar.gz" luarocks-${LUAROCKS_VERSION}

WORKDIR ${RPMBUILD_ROOT}

RUN rpmbuild -ba SPECS/luarocks.spec

FROM rpm-builder AS gateway-rockspecs-native

COPY dependencies/rpm-specs/gateway-rockspecs-native/gateway-rockspecs-native.spec ${RPMBUILD_ROOT}/SPECS/gateway-rockspecs-native.spec
COPY dependencies/rpm-specs/gateway-rockspecs-native/licenses.xml ${RPMBUILD_ROOT}/SOURCES/licenses.xml
COPY dependencies/rpm-specs/gateway-rockspecs-native/source_rocks/* ${RPMBUILD_ROOT}/SOURCES/
RUN yum install -y libyaml-devel

# TODO: fix this later - uncomment for local build
# RUN yum localinstall -y https://rpmfind.net/linux/centos/8-stream/AppStream/x86_64/os/Packages/rpmdevtools-8.10-8.el8.noarch.rpm

# install luarocks from previous build stage
ARG LUAROCKS_VERSION="2.3.0-105.el8"
ARG OPENRESTY_RPM_VERSION="1.19.3-123.el8"
COPY --from=openresty-pcre /root/rpmbuild/RPMS /tmp/openresty-pcre/RPMS
COPY --from=openresty-zlib /root/rpmbuild/RPMS /tmp/openresty-zlib/RPMS
COPY --from=opentracing-cpp /root/rpmbuild/RPMS /tmp/opentracing-cpp/RPMS
COPY --from=openresty /root/rpmbuild/RPMS /tmp/openresty/RPMS
COPY --from=luarocks /root/rpmbuild/RPMS /tmp/luarocks/RPMS

RUN yum localinstall --assumeyes \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-devel-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-1.2.11-122.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-devel-1.2.11-122.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/libopentracing-cpp1-1.3.0-132.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/opentracing-cpp-devel-1.3.0-132.el8.`arch`.rpm \
    /tmp/openresty/RPMS/noarch/openresty-resty-${OPENRESTY_RPM_VERSION}.noarch.rpm \
    /tmp/openresty/RPMS/noarch/openresty-opm-${OPENRESTY_RPM_VERSION}.noarch.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-opentelemetry-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-opentracing-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/luarocks/RPMS/`arch`/luarocks-${LUAROCKS_VERSION}.`arch`.rpm

RUN yum-builddep --assumeyes SPECS/gateway-rockspecs-native.spec

WORKDIR ${RPMBUILD_ROOT}

RUN rpmbuild -ba SPECS/gateway-rockspecs-native.spec


FROM rpm-builder AS gateway-rockspecs

COPY dependencies/rpm-specs/gateway-rockspecs/gateway-rockspecs.spec ${RPMBUILD_ROOT}/SPECS/gateway-rockspecs.spec
COPY dependencies/rpm-specs/gateway-rockspecs/licenses.xml ${RPMBUILD_ROOT}/SOURCES/licenses.xml
COPY dependencies/rpm-specs/gateway-rockspecs/source_rocks/* ${RPMBUILD_ROOT}/SOURCES/

# TODO: fix this later - uncomment for local build
# RUN yum localinstall -y https://rpmfind.net/linux/centos/8-stream/AppStream/x86_64/os/Packages/rpmdevtools-8.10-8.el8.noarch.rpm

# install RPMs from previous build stages
ARG LUAROCKS_VERSION="2.3.0-105.el8"
ARG OPENRESTY_RPM_VERSION="1.19.3-123.el8"
ARG GATEWAY_ROCKSPECS_NATIVE_VERSION="1.0.0-123.el8"

COPY --from=openresty-pcre /root/rpmbuild/RPMS /tmp/openresty-pcre/RPMS
COPY --from=openresty-zlib /root/rpmbuild/RPMS /tmp/openresty-zlib/RPMS
COPY --from=opentracing-cpp /root/rpmbuild/RPMS /tmp/opentracing-cpp/RPMS
COPY --from=openresty /root/rpmbuild/RPMS /tmp/openresty/RPMS
COPY --from=luarocks /root/rpmbuild/RPMS /tmp/luarocks/RPMS
COPY --from=gateway-rockspecs-native /root/rpmbuild/RPMS /tmp/gateway-rockspecs-native/RPMS

RUN yum localinstall --assumeyes \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-devel-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-1.2.11-122.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-devel-1.2.11-122.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/libopentracing-cpp1-1.3.0-132.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/opentracing-cpp-devel-1.3.0-132.el8.`arch`.rpm \
    /tmp/openresty/RPMS/noarch/openresty-resty-${OPENRESTY_RPM_VERSION}.noarch.rpm \
    /tmp/openresty/RPMS/noarch/openresty-opm-${OPENRESTY_RPM_VERSION}.noarch.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-opentelemetry-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-opentracing-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/luarocks/RPMS/`arch`/luarocks-${LUAROCKS_VERSION}.`arch`.rpm \
    /tmp/gateway-rockspecs-native/RPMS/`arch`/gateway-rockspecs-native-${GATEWAY_ROCKSPECS_NATIVE_VERSION}.`arch`.rpm

RUN yum-builddep --assumeyes SPECS/gateway-rockspecs.spec

RUN rpmbuild -ba SPECS/gateway-rockspecs.spec

FROM registry.access.redhat.com/ubi8/ubi:8.10-1132.1731461736 AS apicast

LABEL summary="3scale's API gateway (APIcast) is an OpenResty application which consists of two parts: Nginx configuration and Lua files." \
      description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.display-name="3scale API gateway (APIcast)" \
      io.openshift.expose-services="8080:apicast" \
      io.openshift.tags="integration, nginx, lua, openresty, api, gateway, 3scale, rhamp"

# Labels consumed by Red Hat build service
LABEL com.redhat.component="3scale-amp-apicast-gateway-container" \
      name="3scale-amp2/apicast-gateway-rhel8" \
      version="1.25.0"\
      upstream_repo="${CI_APICAST_UPSTREAM_URL}" \
      upstream_ref="${CI_APICAST_UPSTREAM_COMMIT}" \
      maintainer="3scale-engineering@redhat.com"

ENV AUTO_UPDATE_INTERVAL=0 \
    # The $HOME is not set by default, but some applications needs this variable
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH

EXPOSE 8080

WORKDIR /tmp

ARG BUILD_TYPE=brew
ARG OPENRESTY_RPM_VERSION="1.19.3-123.el8"
ARG LUAROCKS_VERSION="2.3.0-105.el8"
ARG GATEWAY_ROCKSPECS_VERSION="2.10.0-102.el8"
ARG GATEWAY_ROCKSPECS_NATIVE_VERSION="1.0.0-123.el8"
ARG JAEGERTRACING_CPP_CLIENT_RPM_VERSION="0.3.1-16.el8"

# Copy the upstream sources from cachito integration
COPY gateway /opt/app-root/src

# Copy *.rpm files to /tmp/ so we can inject local rpms for local build
#ADD apicast-*.tar.gz /tmp/

# Copy *.rpm files from earlier stages to /tmp/ so we can install RPMs
WORKDIR ${RPMBUILD_ROOT}

# TODO: fix this later - uncomment for local build
#COPY tmp/annobin-annocheck-10.67-3.el8.x86_64.rpm /tmp/annobin-annocheck-10.67-3.el8.x86_64.rpm
#RUN yum localinstall --assumeyes \
#    /tmp/annobin-annocheck-10.67-3.el8.x86_64.rpm
RUN yum install --assumeyes gcc-toolset-12-annobin-annocheck

# Copy *.rpm files from earlier stages to /tmp/ so we can install RPMs
COPY --from=openresty-pcre /root/rpmbuild/RPMS /tmp/openresty-pcre/RPMS
COPY --from=openresty-zlib /root/rpmbuild/RPMS /tmp/openresty-zlib/RPMS
COPY --from=opentracing-cpp /root/rpmbuild/RPMS /tmp/opentracing-cpp/RPMS
COPY --from=openresty /root/rpmbuild/RPMS /tmp/openresty/RPMS
COPY --from=luarocks /root/rpmbuild/RPMS /tmp/luarocks/RPMS
COPY --from=gateway-rockspecs-native /root/rpmbuild/RPMS /tmp/gateway-rockspecs-native/RPMS
COPY --from=gateway-rockspecs /root/rpmbuild/RPMS /tmp/gateway-rockspecs/RPMS

RUN yum localinstall --assumeyes \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-pcre/RPMS/`arch`/openresty-pcre-devel-8.44-126.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-1.2.11-122.el8.`arch`.rpm  \
    /tmp/openresty-zlib/RPMS/`arch`/openresty-zlib-devel-1.2.11-122.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/libopentracing-cpp1-1.3.0-132.el8.`arch`.rpm  \
    /tmp/opentracing-cpp/RPMS/`arch`/opentracing-cpp-devel-1.3.0-132.el8.`arch`.rpm \
    /tmp/openresty/RPMS/noarch/openresty-resty-${OPENRESTY_RPM_VERSION}.noarch.rpm \
    /tmp/openresty/RPMS/noarch/openresty-opm-${OPENRESTY_RPM_VERSION}.noarch.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-opentelemetry-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-opentracing-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/openresty/RPMS/`arch`/openresty-${OPENRESTY_RPM_VERSION}.`arch`.rpm \
    /tmp/luarocks/RPMS/`arch`/luarocks-${LUAROCKS_VERSION}.`arch`.rpm \
    /tmp/gateway-rockspecs-native/RPMS/`arch`/gateway-rockspecs-native-${GATEWAY_ROCKSPECS_NATIVE_VERSION}.`arch`.rpm \
    /tmp/gateway-rockspecs/RPMS/noarch/gateway-rockspecs-${GATEWAY_ROCKSPECS_VERSION}.noarch.rpm

# FIXME/Yorgos: see if this is still required
#RUN PKGS="jaegertracing-cpp-client-${JAEGERTRACING_CPP_CLIENT_RPM_VERSION}" && \
#    mkdir -p "$HOME" && \
#    yum -y --setopt=tsflags=nodocs install $PKGS && \
#    rpm -V $PKGS && \
#    yum clean all -y

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

RUN mkdir -p /root/licenses/3scale-amp-apicast-gateway && \
    cp /usr/share/licenses/gateway-rockspecs/licenses.xml /root/licenses/3scale-amp-apicast-gateway/licenses.xml

COPY dependencies/container-entrypoint /usr/local/bin/container-entrypoint

RUN ln --verbose --symbolic /opt/app-root/src /opt/app-root/app && \
    ln --verbose --symbolic /opt/app-root/bin /opt/app-root/scripts

ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"

WORKDIR /opt/app-root/app

RUN \
    ln --verbose --symbolic /opt/app-root/src/bin /opt/app-root/bin && \
    ln --verbose --symbolic /opt/app-root/src/http.d /opt/app-root/http.d && \
    ln --verbose --symbolic --force /etc/ssl/certs/ca-bundle.crt "/opt/app-root/src/conf" && \
    chmod --verbose g+w "${HOME}" "${HOME}"/* "${HOME}/http.d" && \
    chown -R 1001:0 /opt/app-root

USER 1001

ENV LUA_CPATH "./?.so;/usr/lib64/lua/5.1/?.so;/usr/lib64/lua/5.1/loadall.so;/usr/local/lib64/lua/5.1/?.so"
ENV LUA_PATH "/usr/lib64/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/*/?.lua;"

WORKDIR /opt/app-root
ENTRYPOINT ["container-entrypoint"]
CMD ["scripts/run"]
