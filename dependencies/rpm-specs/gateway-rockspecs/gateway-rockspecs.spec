%global meadalpha %{nil}
%global meadrel %{nil}
%global version_major 2
%global version_minor 10
%global version_micro 0
Name: gateway-rockspecs
Version: %{version_major}.%{version_minor}.%{version_micro}
Release: 102%{?dist}
Summary: Lua Dependencies for 3scale API gateway (APIcast).
# router and inspect are MIT, lua-resty is BSD, lua-resty-jwt is Apache.
License: MIT and BSD-2-Clause and Apache
URL: https://github.com/3scale/apicast
BuildArch: noarch

Source0: licenses.xml
Source1: lua-resty-http-0.17.1-0.src.rock
Source2: router-2.1-0.src.rock
Source3: inspect-3.1.1-0.src.rock
Source4: lua-resty-jwt-0.2.0-0.src.rock
Source5: lua-resty-url-0.3.5-1.src.rock
Source6: lua-resty-env-0.4.0-1.src.rock
Source7: liquid-0.2.0-2.src.rock
Source8: penlight-1.13.1-1.src.rock
Source9: argparse-0.6.0-1.src.rock
Source10: lua-resty-execvp-0.1.1-1.src.rock
Source11: lua-resty-jit-uuid-0.0.7-1.src.rock
Source12: nginx-lua-prometheus-0.20181120-2.src.rock
Source13: lua-resty-iputils-0.3.0-1.src.rock
Source14: net-url-0.9-1.src.rock
Source15: jsonschema-0.8-0.src.rock
Source16: lua-rover-scm-1.src.rock
Source17: date-2.2-2.src.rock


BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: luarocks rpm-build redhat-rpm-config
# Using requires so we can regenerate the manifest on installation.
Requires: luarocks
Requires: gateway-rockspecs-native

%description
RPM to bundle required Lua dependencies for AMP APIcast Gateway.

%prep
%autosetup -T -c %{name}-%{version}

%install
mkdir -p  %{buildroot}/etc/profile.d
echo 'export LUA_PATH="/usr/lib64/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua"' > %{buildroot}/etc/profile.d/lua_path.sh

export LUA_PATH="/usr/lib64/lua/5.1/?.lua;"
for source in "%{_sourcedir}"/*.src.rock; do
  luarocks install --deps-mode=none --tree %{buildroot}/usr/local "$source"
done
# Remove manifest (will be re-created at post to avoid owning it
rm -f %{buildroot}/usr/local/lib64/luarocks/rocks/manifest

# Install licenses in standard location
cp "%{_sourcedir}"/licenses.xml .

# Fix issues on lua-rover bin
sed -i 's|%{buildroot}||g' %{buildroot}/usr/local/bin/rover

%post
export LUA_PATH="/usr/lib64/lua/5.1/?.lua"
luarocks-admin --tree=/usr/local  make_manifest --local-tree

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/local/lib64/luarocks/
/usr/local/share/lua/
/usr/local/bin/rover
/etc/profile.d/lua_path.sh
%license licenses.xml

%changelog

* Fri Dec 02 2022 Yorgos Saslis <gsaslisl@redhat.com> - 2.10.0-1
- Minor version bump to clarify lua-liquid dependency bump that already happened in 2.9.6-12

* Fri Jul 15 2022 Eguzki Astiz Lezaun <eastizle@redhat.com> - 2.9.6-12
- Updated lua-liquid dependency

* Thu Jan 20 2022 CPaaS User <dmarin@redhat.com> - 2.9.6-0.1
- Date filter support on liquid

* Mon Sep 20 2021 Eloy Coto <ecotoper@redhat.com> - 2.9.5-0.1
- Updated luafilesystem-ffi

* Thu Jul 01 2021 Eloy Coto <ecotoper@redhat.com> - 2.9.4-0.11
- Added lua-rover and net-url and fix ENV variables

* Thu Jun 17 2021 Eloy Coto <ecotoper@redhat.com> - 2.9.3-0.2
- Updated lua-liquid dependency

* Fri Jun 26 2020  Eloy Coto <ecotoper@redhat.com> - 2.9.2-0
- Update lua-liquid dependency

* Mon Jan 20 2020 Eloy Coto <ecotoper@redhat.com> - 2.8.1-0
- Update lua-liquid dependency

* Sat Jan 11 2020 Eloy Coto <ecotoper@redhat.com>
- Update dependencies for APIcast AMP 2.8

* Tue Jun 18 2019 David Ortiz <dortiz@redhat.com>
- Update dependencies for APIcast AMP 2.6

* Mon Mar 25 2019 Fernando Nasser <fnasser@redhat.com> - 1.5.0-4
- Use the new license macro

* Wed Mar 13 2019 Fernando Nasser <fnasser@redhat.com> - 1.5.0-3
- Remove manifest before installation

* Wed Mar 13 2019 David Ortiz <dortiz@redhat.com> - 1.5.0-2
- Rebuild without natives

* Tue Mar 12 2019 David Ortiz <dortiz@redhat.com>
- Update dependencies for APIcast AMP 2.5
* Wed Oct 24 2018 David Ortiz <dortiz@redhat.com>
- Update dependencies for APIcast AMP 2.4
* Fri Aug 31 2018 Michal Cichra <mcichra@redhat.com>
- Update dependencies for APIcast AMP 2.3
* Wed Feb 28 2018 Michal Cichra <mcichra@redhat.com>
- Update dependencies for APIcast AMP 2.2
* Thu Aug 24 2017 Michal Cichra <mcichra@redhat.com>
- Fix invalid licenses.xml
* Thu Aug 24 2017 Michal Cichra <mcichra@redhat.com>
- Add licenses.xml
* Wed Jul 26 2017 Michal Cichra <mcichra@redhat.com>
- Update dependencies to match AMP APIcast 2.1.0 ER1
* Thu Mar 23 2017 Nick Cross <ncross@redhat.com>
- Add lua-resty-jwt-0.1.9-0.src.rock
* Wed Oct 12 2016 Nick Cross <ncross@redhat.com>
-
