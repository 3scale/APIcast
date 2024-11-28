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
* Fri Dec 02 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-23
- Bump release

* Mon Oct 03 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-22
- Bump release

* Wed Feb 23 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-21
- Bump release

* Wed Feb 23 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-20
- Bump release

* Wed Feb 23 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-19
- Bump release

* Wed Feb 09 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-18
- Bump release

* Wed Feb 09 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-17
- Bump release

* Wed Feb 09 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-16
- Bump release

* Wed Feb 09 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-15
- Bump release

* Wed Jan 26 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-14
- Bump release

* Wed Jan 26 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-13
- Bump release

* Mon Jan 24 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.16
- Bump release

* Thu Jan 13 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.15
- Bump release

* Wed Jan 12 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.14
- Bump release

* Wed Jan 12 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.13
- Bump release

* Wed Jan 12 2022 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.12
- Bump release

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.11
- Bump release

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.10
- Bump release

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.9
- Bump release

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.8
- Bump release

* Fri Jul 02 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.7
- Bump release

* Fri Jul 02 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.6
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.5
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.4
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-12.3
- Bump release

* Thu May 06 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-11.2
- Bump release

* Thu May 06 2021 CPaaS User <cpaas-ops@redhat.com> - 1.0.0-11.1
- Bump release

* Mon Jan 20 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.0.0-8
Built by CPaaS

* Mon Jan 20 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.0.0-7
Built by CPaaS

* Mon Jan 20 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.0.0-6
Built by CPaaS

* Wed Jan 15 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.0.0-5
Built by CPaaS

* Wed Jan 15 2020 cpaas-ops <cpaas-ops@redhat.com> - 1.0.0-4
Built by CPaaS

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

