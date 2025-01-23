%global commitid f3c1f42601d13504c68e2bc81c60604f0de055dd
%global meadalpha %{nil}
%global meadrel %{nil}
%global version_major 1
%global version_minor 3
%global version_micro 0

#
# spec file for package opentracing-cpp
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           opentracing-cpp
Version:        %{version_major}.%{version_minor}.%{version_micro}
Release:        132%{?dist}
Summary:        OpenTracing C++ API
License:        MIT
Group:          Development/Languages/C and C++
Url:            http://opentracing.io/
Source:         opentracing-cpp-%{version}
# Patch for cmake to handle lib/lib64 properly
BuildRequires:  gcc-c++ cmake3
%description
C++ implementation of the OpenTracing API.

%package -n libopentracing-cpp1
Summary:        OpenTracing C++ API
Group:          System/Libraries

%description -n libopentracing-cpp1
C++ implementation of the OpenTracing API.

%package devel
Summary:        Development files for the OpenTracing C++ API
Group:          Development/Languages/C and C++
Requires:       libopentracing-cpp1 = %{version}-%{release}

%description devel
Development files for the C++ implementation of the OpenTracing API.

%package devel-static
Summary:        Static libraties for the OpenTracing C++ API
Group:          Development/Languages/C and C++
Requires:       %{name}-devel = %{version}

%description devel-static
Static libraries for the C++ implementation of the OpenTracing API.

%global _libdir /usr/lib/

%prep
cp -R ../SOURCES/%{name}-%{version} %{name}-%{version}
%setup -q -T -D -n %{name}-%{version}

%build
%cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_FLAGS=-fPIC -DBUILD_DYNAMIC_LIBS=ON -DBUILD_STATIC_LIBS=ON -DBUILD_TESTING=OFF -DLIB_INSTALL_DIR=/usr/%{_lib}
#%%make_jobs
# (the above macro only exists on Suse)
make %{?_smp_mflags}

%install
#%%cmake_install
# We dont have the above macro
%make_install
# FIXME: cmake_install.cmake does not seem to know about lib64
# See Patch0
#mv %{?buildroot}/usr/lib %{?buildroot}/usr/%{_lib}

%post -n libopentracing-cpp1 -p /sbin/ldconfig

%postun -n libopentracing-cpp1 -p /sbin/ldconfig

%files -n libopentracing-cpp1
%license LICENSE
%dir %{_libdir}/cmake/OpenTracing
%{_libdir}/cmake/OpenTracing/OpenTracingConfig.cmake
%{_libdir}/cmake/OpenTracing/OpenTracingConfigVersion.cmake
%{_libdir}/cmake/OpenTracing/OpenTracingTargets-relwithdebinfo.cmake
%{_libdir}/cmake/OpenTracing/OpenTracingTargets.cmake
%{_libdir}/libopentracing.so.1
%{_libdir}/libopentracing.so.%{version_major}.%{version_minor}.%{version_micro}
%{_libdir}/libopentracing_mocktracer.so.%{version_major}
%{_libdir}/libopentracing_mocktracer.so.%{version_major}.%{version_minor}.%{version_micro}

%files devel
%dir %{_includedir}/opentracing
%{_includedir}/opentracing/config.h
%{_includedir}/opentracing/dynamic_load.h
%{_includedir}/opentracing/noop.h
%{_includedir}/opentracing/propagation.h
%{_includedir}/opentracing/span.h
%{_includedir}/opentracing/string_view.h
%{_includedir}/opentracing/tracer.h
%{_includedir}/opentracing/tracer_factory.h
%{_includedir}/opentracing/util.h
%{_includedir}/opentracing/value.h
%{_includedir}/opentracing/version.h

%dir %{_includedir}/opentracing/expected
%{_includedir}/opentracing/expected/expected.hpp

# These are only available on 1.4.0 onwards
#%%dir %{_includedir}/opentracing/ext
#%%{_includedir}/opentracing/ext/tags.h

%dir %{_includedir}/opentracing/mocktracer
%{_includedir}/opentracing/mocktracer/in_memory_recorder.h
%{_includedir}/opentracing/mocktracer/json.h
%{_includedir}/opentracing/mocktracer/json_recorder.h
%{_includedir}/opentracing/mocktracer/recorder.h
%{_includedir}/opentracing/mocktracer/tracer.h
%{_includedir}/opentracing/mocktracer/tracer_factory.h

%dir %{_includedir}/opentracing/variant
%{_includedir}/opentracing/variant/recursive_wrapper.hpp
%{_includedir}/opentracing/variant/variant.hpp

%{_libdir}/libopentracing.so
%{_libdir}/libopentracing_mocktracer.so

%files devel-static
%{_libdir}/libopentracing.a
%{_libdir}/libopentracing_mocktracer.a

%doc README.md COPYING

%changelog

* Wed Oct 17 2018 Fernando Nasser <fnasser@redhat.com> - 1.3.0
- Build 1.3.0

* Sat Jul 28 2018 jengelh@inai.de
- Fix RPM groups, edit description for better grammar.
* Mon Jun 25 2018 mrostecki@suse.com
- Make use of %%license macro
* Tue Jun 19 2018 mrostecki@suse.com
- Fix ldconfig calls
* Wed May  2 2018 mrostecki@suse.com
- Initial commit
