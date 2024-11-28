%global version_release 1
%global commitid 189070e331150d40d360b77699ccd8e38bc1ae05
%global apicastModule apicast-nginx-module-v0.4
%global meadalpha %{nil}
%global meadrel %{nil}
%global version_major 1
%global version_minor 19
%global version_micro 3

%global grpc_version                        v1.49.2
%global opentelemetry_proto_version         v0.19.0
%global opentelemetry_cpp_contrib_version   1ec94c82095bab61f06c7393b6f3272469d285af
%global opentelemetry_cpp_version           v1.8.1
%global orprefix            %{_usr}/local/%{name}
%global zlib_prefix         %{orprefix}/zlib
%global pcre_prefix         %{orprefix}/pcre
%global otel_install                        %{_builddir}/otel
%global grpc_builddir                       %{_builddir}/grpc-%{grpc_version}
%global otel_cpp_builddir                   %{_builddir}/opentelemetry-cpp-%{opentelemetry_cpp_version}
%global openresty_builddir                  %{_builddir}/openresty-%{commitid}
%global lib_path                            /opt/app-root/lib
%global gcc12_path                          /opt/rh/gcc-toolset-12/root/bin

%if 0%{?fedora} >= 27
%undefine _debugsource_packages
%undefine _debuginfo_subpackages
%endif

Name:           openresty
Version:        %{version_major}.%{version_minor}.%{version_micro}
Release:        123%{?dist}
Summary:        OpenResty, scalable web platform by extending NGINX with Lua
Group:          System Environment/Daemons

# BSD License (two clause)
# http://www.freebsd.org/copyright/freebsd-license.html
License:        BSD
URL:            https://openresty.org/

Source0: openresty-%{commitid}.tar.gz
Source1: array-var-nginx-module-v0.05.tar.gz
Source2: drizzle-nginx-module-v0.1.11.tar.gz
Source3: echo-nginx-module-v0.62.tar.gz
Source4: encrypted-session-nginx-module-v0.08.tar.gz
Source5: form-input-nginx-module-v0.12.tar.gz
Source6: headers-more-nginx-module-v0.33.tar.gz
Source7: iconv-nginx-module-v0.14.tar.gz
Source8: lua-cjson-2.1.0.8.tar.gz
Source9: luajit2-v2.1-20201027-product-zfixes.tar.gz
Source10: lua-nginx-module-v0.10.19.tar.gz
Source11: lua-rds-parser-v0.06.tar.gz
Source12: lua-redis-parser-v0.13.tar.gz
Source13: lua-resty-core-v0.1.21.tar.gz
Source14: lua-resty-dns-v0.21.tar.gz
Source15: lua-resty-limit-traffic-v0.07.tar.gz
Source16: lua-resty-lock-v0.08.tar.gz
Source17: lua-resty-lrucache-v0.10.tar.gz
Source18: lua-resty-memcached-v0.15.tar.gz
Source19: lua-resty-mysql-v0.23.tar.gz
Source20: lua-resty-redis-v0.29.tar.gz
Source21: lua-resty-shell-v0.03.tar.gz
Source22: lua-resty-signal-v0.02.tar.gz
Source23: lua-resty-string-v0.12.tar.gz
Source24: lua-resty-upload-v0.10.tar.gz
Source25: lua-resty-upstream-healthcheck-v0.06.tar.gz
Source26: lua-resty-websocket-v0.08.tar.gz
Source27: lua-tablepool-v0.01.tar.gz
Source28: lua-upstream-nginx-module-v0.07.tar.gz
Source29: memc-nginx-module-v0.19.tar.gz
Source30: nginx-release-1.19.3-product-4.tar.gz
Source31: ngx_coolkit-0.2.tar.gz
Source32: ngx_devel_kit-v0.3.1.tar.gz
Source33: ngx_http_redis-0.3.7.tar.gz
Source34: ngx_postgres-1.0.tar.gz
Source35: opm-v0.0.5.tar.gz
Source36: rds-csv-nginx-module-v0.09.tar.gz
Source37: rds-json-nginx-module-v0.15.tar.gz
Source38: redis2-nginx-module-v0.15.tar.gz
Source39: resty-cli-v0.27.tar.gz
Source40: set-misc-nginx-module-v0.32.tar.gz
Source41: srcache-nginx-module-v0.32.tar.gz
Source42: stream-lua-nginx-module-v0.0.9.tar.gz
Source43: xss-nginx-module-v0.06.tar.gz
Source44: nginx-opentracing-v0.3.0.tar.gz
Source45: %{apicastModule}.tar.gz
Source46: grpc-%{grpc_version}.tar.gz
Source47: opentelemetry-cpp-%{opentelemetry_cpp_version}.tar.gz
Source48: opentelemetry-cpp-contrib-%{opentelemetry_cpp_contrib_version}.tar.gz
Source49: opentelemetry-proto-%{opentelemetry_proto_version}.tar.gz

BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildRequires:  make, cmake, perl, systemtap-sdt-devel, git, annobin-annocheck
BuildRequires:  perl-File-Temp, dos2unix, pcre-devel, openssl-devel
BuildRequires:  gcc, gcc-c++
BuildRequires:  gcc-toolset-12-gcc, gcc-toolset-12-gcc-c++
BuildRequires:  openresty-zlib-devel >= 1.2.11-3
BuildRequires:  openresty-pcre-devel >= 8.42-1
BuildRequires:  opentracing-cpp-devel = 1.3.0
Requires:       openresty-zlib >= 1.2.11-3
Requires:       openresty-pcre >= 8.42-1


AutoReqProv:        no


%description
This package contains the core server for OpenResty. Built for production
uses.

OpenResty is a full-fledged web platform by integrating the standard Nginx
core, LuaJIT, many carefully written Lua libraries, lots of high quality
3rd-party Nginx modules, and most of their external dependencies. It is
designed to help developers easily build scalable web applications, web
services, and dynamic web gateways.

By taking advantage of various well-designed Nginx modules (most of which
are developed by the OpenResty team themselves), OpenResty effectively
turns the nginx server into a powerful web app server, in which the web
developers can use the Lua programming language to script various existing
nginx C modules and Lua modules and construct extremely high-performance
web applications that are capable to handle 10K ~ 1000K+ connections in
a single box.


%package resty

Summary:        OpenResty command-line utility, resty
Group:          Development/Tools
Requires:       perl, openresty >= %{version}-%{release}
Requires:       perl(File::Spec), perl(FindBin), perl(List::Util), perl(Getopt::Long), perl(File::Temp), perl(POSIX), perl(Time::HiRes)

%if 0%{?fedora} >= 10 || 0%{?rhel} >= 6 || 0%{?centos} >= 6
BuildArch:      noarch
%endif


%description resty
This package contains the "resty" command-line utility for OpenResty, which
runs OpenResty Lua scripts on the terminal using a headless NGINX behind the
scene.

OpenResty is a full-fledged web platform by integrating the standard Nginx
core, LuaJIT, many carefully written Lua libraries, lots of high quality
3rd-party Nginx modules, and most of their external dependencies. It is
designed to help developers easily build scalable web applications, web
services, and dynamic web gateways.



%package opm

Summary:        OpenResty Package Manager
Group:          Development/Tools
Requires:       perl, openresty >= %{version}-%{release}, perl(Digest::MD5)
Requires:       openresty-resty >= %{version}-%{release}
Requires:       curl, tar, gzip
Requires:       perl(Encode), perl(FindBin), perl(File::Find), perl(File::Path), perl(File::Spec), perl(Cwd), perl(Digest::MD5), perl(File::Copy), perl(File::Temp), perl(Getopt::Long)

%if 0%{?fedora} >= 10 || 0%{?rhel} >= 6 || 0%{?centos} >= 6
BuildArch:      noarch
%endif


%description opm
This package provides the client side tool, opm, for OpenResty Pakcage Manager (OPM).

%package opentracing

Summary:        Opentracing module


%description opentracing
This package provides the opentracing module in Openresty.

%package opentelemetry

Summary:        Opentelemetry module

%description opentelemetry
This package provides the opentelemetry module in Openresty.

%prep
ls -la %{_sourcedir}
%setup -q -n "openresty-%{commitid}"
%setup -q -D -T -b 46 -n "openresty-%{commitid}"
%setup -q -D -T -b 47 -n "openresty-%{commitid}"
%setup -q -D -T -a 48 -n "openresty-%{commitid}"
%setup -q -D -T -b 49 -n "openresty-%{commitid}"
cp %{SOURCE0} .
cp %{SOURCE1} .
cp %{SOURCE2} .
cp %{SOURCE3} .
cp %{SOURCE4} .
cp %{SOURCE5} .
cp %{SOURCE6} .
cp %{SOURCE7} .
cp %{SOURCE8} .
cp %{SOURCE9} .
cp %{SOURCE10} .
cp %{SOURCE11} .
cp %{SOURCE12} .
cp %{SOURCE13} .
cp %{SOURCE14} .
cp %{SOURCE15} .
cp %{SOURCE16} .
cp %{SOURCE17} .
cp %{SOURCE18} .
cp %{SOURCE19} .
cp %{SOURCE20} .
cp %{SOURCE21} .
cp %{SOURCE22} .
cp %{SOURCE23} .
cp %{SOURCE24} .
cp %{SOURCE25} .
cp %{SOURCE26} .
cp %{SOURCE27} .
cp %{SOURCE28} .
cp %{SOURCE29} .
cp %{SOURCE30} .
cp %{SOURCE31} .
cp %{SOURCE32} .
cp %{SOURCE33} .
cp %{SOURCE34} .
cp %{SOURCE35} .
cp %{SOURCE36} .
cp %{SOURCE37} .
cp %{SOURCE38} .
cp %{SOURCE39} .
cp %{SOURCE40} .
cp %{SOURCE41} .
cp %{SOURCE42} .
cp %{SOURCE43} .
tar xzf %{SOURCE44}
tar xzfv %{SOURCE45}

%build
ls -al %{_builddir}
mkdir -p %{grpc_builddir}/cmake/build
cd %{grpc_builddir}/cmake/build

cmake -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DCMAKE_C_COMPILER=%{gcc12_path}/gcc \
    -DCMAKE_CXX_COMPILER=%{gcc12_path}/g++ \
    -DCMAKE_INSTALL_PREFIX=%{otel_install} \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF \
    -DgRPC_SSL_PROVIDER=package \
    -DgRPC_ZLIB_PROVIDER=package \
    ../..
make %{?_smp_mflags} VERBOSE=1
make install

export LD_LIBRARY_PATH=%{otel_install}/lib:%{otel_install}/lib64:$LD_LIBRARY_PATH

#
rm -r %{otel_cpp_builddir}/third_party/opentelemetry-proto || exit 0
mkdir -p %{otel_cpp_builddir}/build
cd %{otel_cpp_builddir}/build
cmake -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_C_COMPILER=%{gcc12_path}/gcc \
    -DCMAKE_CXX_COMPILER=%{gcc12_path}/g++ \
    -DCMAKE_INSTALL_PREFIX=%{otel_install} \
    -DCMAKE_PREFIX_PATH=%{otel_install} \
    -DOTELCPP_PROTO_PATH=%{_builddir}/opentelemetry-proto-%{opentelemetry_proto_version} \
    -DWITH_OTLP=ON \
    -DWITH_OTLP_GRPC=ON \
    -DWITH_OTLP_HTTP=OFF \
    -DBUILD_TESTING=OFF \
    -DWITH_EXAMPLES=OFF \
    -DWITH_ZIPKIN=OFF \
    -DWITH_JAEGER=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    ..
make %{?_smp_mflags} VERBOSE=1
make install

export LDFLAGS="%{?__global_ldflags}"
export CFLAGS="%{optflags}"
export FORCE_CACHE=true

cd %{openresty_builddir}
make %{?_smp_mflags}
ls -lah
cd $(ls -1 | grep openresty | grep -v "tar.gz")
ls -lah bundle/
./configure --help
./configure \
    --prefix="%{orprefix}" \
    --with-cc-opt="%{optflags} -DNGX_LUA_ABORT_AT_PANIC -I%{otel_install}/include -I%{zlib_prefix}/include -I%{pcre_prefix}/include -I$(pwd)/../%{apicastModule}/ " \
    --with-ld-opt="%{?__global_ldflags} -L%{zlib_prefix}/lib -L%{pcre_prefix}/lib -L%{otel_install}/lib -L%{otel_install}/lib64 -Wl,-rpath,%{zlib_prefix}/lib:%{pcre_prefix}/lib -L$(pwd)/../%{apicastModule}/ " \
    --with-pcre-jit \
    --without-http_rds_json_module \
    --without-http_rds_csv_module \
    --without-lua_rds_parser \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-http_v2_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_secure_link_module \
    --with-http_random_index_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-threads \
    --add-module="../%{apicastModule}/" \
    --add-dynamic-module="../nginx-opentracing-v0.3.0/opentracing" \
    --add-dynamic-module="../opentelemetry-cpp-contrib-%{opentelemetry_cpp_contrib_version}/instrumentation/nginx" \
    --with-luajit-target-strip="Q='' CFLAGS='' TARGET_XCFLAGS='-D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE' TARGET_FLAGS='%{optflags}' HOST_CC='%{__cc}' STATIC_CC='%{__cc}' DYNAMIC_CC='%{__cc} -fPIC' HOST_CFLAGS='%{optflags}' HOST_LDFLAGS='%{?__global_ldflags}'"

make %{?_smp_mflags}

%install
cd $(ls -1 | grep openresty | grep -v "tar.gz")
make install DESTDIR=%{buildroot}

rm -rf %{buildroot}%{orprefix}/luajit/share/man
rm -rf %{buildroot}%{orprefix}/luajit/lib/libluajit-5.1.a

mkdir -p %{buildroot}%{_bindir}
ln -sf %{orprefix}/bin/resty %{buildroot}%{_bindir}/
ln -sf %{orprefix}/bin/opm %{buildroot}%{_bindir}/
ln -sf %{orprefix}/nginx/sbin/nginx %{buildroot}%{_bindir}/%{name}
ln -sf %{orprefix}/luajit/bin/luajit %{buildroot}%{_bindir}/lua
ln -sf %{orprefix}/luajit/bin/luajit %{buildroot}%{_bindir}/luajit

# to silence the check-rpath error
export QA_RPATHS=$[ 0x0002 ]

mkdir -p %{buildroot}%{lib_path}
cp -va %{otel_install}/lib64/. %{buildroot}%{lib_path}
cp -va %{otel_install}/lib/. %{buildroot}%{lib_path}

%check
ls %{buildroot}%{orprefix}/nginx/sbin/nginx
ls %{buildroot}%{orprefix}/luajit/lib/libluajit-5.1.so.2.1.0
ls %{buildroot}%{orprefix}/luajit/bin/luajit-2.1.0-beta3

annocheck -v %{buildroot}%{orprefix}/nginx/sbin/nginx || echo "FAILED"
annocheck -v %{buildroot}%{orprefix}/luajit/lib/libluajit-5.1.so.2.1.0 || echo "FAILED"
annocheck -v %{buildroot}%{orprefix}/luajit/bin/luajit-2.1.0-beta3 || echo "FAILED"

find %{orprefix}

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)

%{_bindir}/%{name}
%{_bindir}/lua
%{_bindir}/luajit
%{orprefix}/bin/*
%{orprefix}/site/lualib/
%{orprefix}/luajit/*
%{orprefix}/lualib/*
%{orprefix}/nginx/html/*
%{orprefix}/nginx/logs/
%{orprefix}/nginx/sbin/*
%config(noreplace) %{orprefix}/nginx/conf/*
%{orprefix}/COPYRIGHT


%files resty
%defattr(-,root,root,-)

%{_bindir}/resty
%{orprefix}/bin/resty


%files opm
%defattr(-,root,root,-)

%{_bindir}/opm
%{orprefix}/bin/opm
%{orprefix}/site/manifest/
%{orprefix}/site/pod/

%files opentracing
%defattr(-,root,root,-)

%{orprefix}/nginx/modules/ngx_http_opentracing_module.so

%files opentelemetry
%defattr(-,root,root,-)

%{orprefix}/nginx/modules/otel_ngx_module.so
%{lib_path}

%changelog
* Tue Oct 24 2023 Eguzki Astiz Lezaun <eastizle@redhat.com> - 1.19.3-123
- CVE-2023-44487

* Mon Jan 30 2023 Eguzki Astiz Lezaun <eastizle@redhat.com> - 1.19.3-21
- Opentelemetry RPM

* Mon Oct 03 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-18
- Bump release

* Wed Feb 23 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-17
- Bump release

* Wed Feb 23 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-16
- Bump release

* Wed Feb 23 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-15
- Bump release

* Wed Feb 09 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-14
- Bump release

* Wed Feb 09 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-13
- Bump release

* Wed Feb 09 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-12
- Bump release

* Wed Feb 09 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-11
- Bump release

* Wed Jan 26 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-10
- Bump release

* Tue Jan 25 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-9
- Bump release

* Mon Jan 24 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-6.27
- Bump release

* Fri Jan 21 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-6.26
- Bump release

* Thu Jan 13 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-6.25
- Bump release

* Thu Jan 13 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-6.22
- Bump release

* Thu Jan 13 2022 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-6.21
- Bump release

* Mon Aug 02 2021 Eloy Coto <ecotoper@redhat.com> - 1.19.3-5.20
- Bump APIcast module

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.20
- Bump release

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.19
- Bump release

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.18
- Bump release

* Fri Jul 02 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.17
- Bump release

* Fri Jul 02 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.16
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.15
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.14
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.13
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-4.12
- Bump release

* Wed Jun 30 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-3.11
- Bump release

* Wed Jun 30 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-3.10
- Bump release

* Wed Jun 30 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-3.9
- Bump release

* Wed Jun 30 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-3.8
- Bump release

* Wed Jun 30 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-3.7
- Bump release

* Wed Jun 30 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-3.6
- Bump release

* Wed Jun 30 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-3.5
- Bump release

* Tue Jun 29 2021 CPaaS User <cpaas-ops@redhat.com> - 1.19.3-3.4
- Bump release

* Thu May 06 2021 CPaaS User <cpaas-ops@redhat.com> - 1.17.6-1.3
- Bump release

* Thu May 06 2021 CPaaS User <cpaas-ops@redhat.com> - 1.17.6-1.2
- Bump release

* Thu May 06 2021 CPaaS User <cpaas-ops@redhat.com> - 1.17.6-1.1
- Bump release

* Thu Apr 15 2021 Eloy Coto 1.17.6.1
- Updated Luajit version

* Mon Jan 20 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.17.4-6
Built by CPaaS

* Mon Jan 20 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.17.4-5
Built by CPaaS

* Mon Jan 20 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.17.4-4
Built by CPaaS

* Wed Jan 15 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.17.4-3
Built by CPaaS

* Wed Jan 15 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.17.4-2
Built by CPaaS

* Thu Jan 9 2020 Eloy Coto 1.17.4.1
- custom Openresty build.
* Thu May 16 2019 Yichun Zhang (agentzh) 1.15.8.1-1
- upgraded openresty to 1.15.8.1.
* Mon May 14 2018 Yichun Zhang (agentzh) 1.13.6.2-1
- upgraded openresty to 1.13.6.2.
* Sun Nov 12 2017 Yichun Zhang (agentzh) 1.13.6.1-1
- upgraded openresty to 1.13.6.1.
* Thu Sep 21 2017 Yichun Zhang (agentzh) 1.11.2.5-2
- enabled -DNGX_LUA_ABORT_AT_PANIC by default.
* Thu Aug 17 2017 Yichun Zhang (agentzh) 1.11.2.5-1
- upgraded OpenResty to 1.11.2.5.
* Tue Jul 11 2017 Yichun Zhang (agentzh) 1.11.2.4-1
- upgraded OpenResty to 1.11.2.4.
* Sat May 27 2017 Yichun Zhang (agentzh) 1.11.2.3-14
- bugfix: the openresty-opm subpackage did not depend on openresty-doc and openresty-resty.
* Sat May 27 2017 Yichun Zhang (agentzh) 1.11.2.3-14
- centos 6 and opensuse do not have the groff-base package.
* Sat May 27 2017 Yichun Zhang (agentzh) 1.11.2.3-13
- openresty-doc now depends on groff-base.
* Thu May 25 2017 Yichun Zhang (agentzh) 1.11.2.3-12
- added missing groff/pod2txt/pod2man dependencies for openresty-doc.
* Thu May 25 2017 Yichun Zhang (agentzh) 1.11.2.3-11
- added missing perl dependencies for openresty-opm, openresty-resty, and openresty-doc.
* Sun May 21 2017 Yichun Zhang (agentzh) 1.11.2.3-10
- removed the geoip nginx module since GeoIP is not available everywhere.
* Fri Apr 21 2017 Yichun Zhang (agentzh)
- upgrade to the OpenResty 1.11.2.3 release: http://openresty.org/en/changelog-1011002.html
* Sat Dec 24 2016 Yichun Zhang
- init script: explicity specify the runlevels 345.
* Wed Dec 14 2016 Yichun Zhang
- opm missing runtime dependencies curl, tar, and gzip.
- enabled http_geoip_module by default.
* Fri Nov 25 2016 Yichun Zhang
- opm missing runtime dependency perl(Digest::MD5)
* Thu Nov 17 2016 Yichun Zhang
- upgraded OpenResty to 1.11.2.2.
* Fri Aug 26 2016 Yichun Zhang
- use dual number mode in our luajit builds which should usually
be faster for web application use cases.
* Wed Aug 24 2016 Yichun Zhang
- bump OpenResty version to 1.11.2.1.
* Tue Aug 23 2016 zxcvbn4038
- use external packages openresty-zlib and openresty-pcre through dynamic linking.
* Thu Jul 14 2016 Yichun Zhang
- enabled more nginx standard modules as well as threads and file aio.
* Sun Jul 10 2016 makerpm
- initial build for OpenResty 1.9.15.1.

