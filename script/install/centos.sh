#!/bin/sh

set -x -e

# Old Centos packages are moved to vault.centos.org
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Stream-*
sed -i 's/mirrorlist/#mirrorlist/g'  /etc/yum.repos.d/CentOS-*

yum install -y yum-utils
yum-config-manager --enable "powertools"

# Remove lua 5.3
yum remove -y lua

# install build and runtime dependencies
yum -y install gcc gcc-c++ make m4 git which iputils bind-utils expat-devel m4\
    wget tar unzip libyaml libyaml-devel \
    perl-local-lib perl-App-cpanminus \
    openssl-devel libev-devel \
    kernel-headers kernel-devel kernel-debug \
    redis systemtap \
    python2-pip elfutils-devel

dnf --enablerepo="debuginfo" debuginfo-install -y "kernel-core-$(uname -r)"
