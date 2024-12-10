%global meadalpha %{nil}
%global meadrel %{nil}
%global version_major 1
%global version_minor 0
%global version_micro 0

%undefine _debugsource_packages

Name: gateway-rockspecs-native
Version: %{version_major}.%{version_minor}.%{version_micro}
Release: 123%{?dist}
Summary: Native Dependencies for 3scale API gateway (APIcast).
License: MIT
URL: https://github.com/3scale/apicast

Source0: licenses.xml
# Source1: https://luarocks.org/manifests/gvvaughan/lyaml-6.2.3-1.src.rock
Source1: lyaml-6.2.3-1.src.rock
Source2: luafilesystem-1.8.0-1.src.rock


BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: luarocks rpm-build redhat-rpm-config libyaml-devel gcc
# Using requires so we can regenerate the manifest on installation.
Requires: luarocks libyaml glibc-devel

%description
RPM to bundle required Native dependencies for AMP APIcast Gateway.

%prep
%autosetup -T -c %{name}-%{version}

%build
# To run debuginfo, if not does not work
ls

%install
export LUA_PATH="./lua_modules/share/lua/5.1/?.lua;./lua_modules/share/lua/5.1/?/init.lua;/usr/lib64/lua/5.1/?.lua;"
for source in "%{_sourcedir}"/*.src.rock; do
  luarocks install --deps-mode=none --tree %{buildroot}/usr/local "$source" \
    CFLAGS="-O2 -g -fpic -Wl,-z,now ${RPM_OPT_FLAGS}"
done
rm -f %{buildroot}/usr/local/%{_lib}/luarocks/rocks/manifest
cp "%{_sourcedir}"/licenses.xml .

%post
export LUA_PATH="/usr/lib64/lua/5.1/?.lua"
luarocks-admin --tree=/usr/local  make_manifest --local-tree

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/local/%{_lib}/luarocks/
/usr/local/share/lua/
/usr/local/%{_lib}/lua/5.1/
%license licenses.xml

%changelog

* Wed Jan 15 2020 Yorgos Saslis <yorgos@redhat.com> - 1.1.0-0
- Use 5.1 path and Luajit from openresty to build it

* Mon Mar 25 2019 Fernando Nasser <fnasser@redhat.com> - 1.0.0-3
- Use the new license macro

* Wed Mar 13 2019 David Ortiz <dortiz@redhat.com> - 1.0.0-2
- -

* Wed Mar 13 2019 David Ortiz <dortiz@redhat.com> - 1.0.0-1
- First build

* Wed Mar 13 2019 David Ortiz <dortiz@redhat.com>
- First version

