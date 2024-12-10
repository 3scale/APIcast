FROM centos:8

RUN yum upgrade -y \
    && dnf install -y 'dnf-command(config-manager)'
RUN yum install -y epel-release git make gcc cmake gcc-c++ which
RUN yum config-manager --add-repo http://packages.dev.3sca.net/dev_packages_3sca_net.repo
RUN dnf --enablerepo=PowerTools install -y libyaml-devel luarocks
RUN yum install -y rpm-build redhat-rpm-config rpmdevtools

RUN mkdir -p /root/rpmbuild/SOURCES/


COPY . /opt/data/
RUN cp /opt/data/licenses.xml /root/rpmbuild/SOURCES/
RUN spectool -g -R /opt/data/*.spec
RUN rpmbuild -ba /opt/data/*.spec
