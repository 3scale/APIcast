Name:               openresty-pcre
Version:            8.44
Release:            126%{?dist}
Summary:            Perl-compatible regular expression library for OpenResty

Group:              System Environment/Libraries

License:            BSD
URL:                http://www.pcre.org/
Source0:            pcre-%{version}

BuildRoot:          %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildRequires:      libtool

AutoReqProv:        no

%define pcre_prefix     /usr/local/openresty/pcre

%description
Perl-compatible regular expression library for use by OpenResty ONLY


%if 0%{?fedora} >= 27
%undefine _debugsource_packages
%undefine _debuginfo_subpackages
%endif

%if 0%{?rhel} >= 8
%undefine _debugsource_packages
%undefine _debuginfo_subpackages
%endif


%package devel
Summary:            Development files for %{name}
Group:              Development/Libraries
Requires:           %{name} = %{version}-%{release}


%description devel
Development files for Perl-compatible regular expression library for use by OpenResty ONLY


%prep
cp -R ../SOURCES/pcre-%{version} pcre-%{version}
%setup -q -T -D -n pcre-%{version}


%build

export CC="gcc -fdiagnostics-color=always"
export CFLAGS="-Wl,-z,now %{optflags}"
./configure \
  --prefix=%{pcre_prefix} \
  --libdir=%{pcre_prefix}/lib \
  --disable-cpp \
%ifarch s390x
  --disable-jit \
%else
  --enable-jit \
%endif
  --enable-utf \
  --enable-unicode-properties
%{make_build} CFLAGS="${CFLAGS}"


%install
make install DESTDIR=%{buildroot}
rm -rf %{buildroot}/%{pcre_prefix}/bin
rm -rf %{buildroot}/%{pcre_prefix}/share
rm -f  %{buildroot}/%{pcre_prefix}/lib/*.la
rm -f  %{buildroot}/%{pcre_prefix}/lib/*pcrecpp*
rm -f  %{buildroot}/%{pcre_prefix}/lib/*pcreposix*
rm -rf %{buildroot}/%{pcre_prefix}/lib/pkgconfig


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
%{pcre_prefix}/lib/*.so*


%files devel
%defattr(-,root,root,-)
%{pcre_prefix}/lib/*.a
%{pcre_prefix}/include/*.h


%changelog
* Fri May 06 2022 CPaaS User <cpaas-ops@redhat.com> - 8.44-26
- Bump release

* Mon Feb 28 2022 CPaaS User <cpaas-ops@redhat.com> - 8.44-25
- Bump release

* Mon Feb 28 2022 CPaaS User <cpaas-ops@redhat.com> - 8.44-24
- Bump release

* Thu Feb 24 2022 CPaaS User <cpaas-ops@redhat.com> - 8.44-23
- Bump release

* Wed Jan 12 2022 CPaaS User <cpaas-ops@redhat.com> - 8.44-13
- Bump release

* Wed Jan 12 2022 CPaaS User <cpaas-ops@redhat.com> - 8.44-12
- Bump release

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 8.44-10
- Bump release

* Mon Jul 05 2021 CPaaS User <cpaas-ops@redhat.com> - 8.44-9
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 8.44-8
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 8.44-7
- Bump release

* Thu Jul 01 2021 CPaaS User <cpaas-ops@redhat.com> - 8.44-6
- Bump release

* Mon May 14 2018 Yichun Zhang (agentzh) 8.42-1
- upgraded openresty-pcre to 8.42.
* Thu Nov 2 2017 Yichun Zhang (agentzh)
- upgraded PCRE to 8.41.
* Sun Mar 19 2017 Yichun Zhang (agentzh)
- upgraded PCRE to 8.40.
* Sat Sep 24 2016 Yichun Zhang
- disable the C++ support in build. thanks luto.
* Tue Aug 23 2016 zxcvbn4038
- initial build for pcre 8.39.
