FROM registry.access.redhat.com/ubi8:8.5

RUN sed -i s/enabled=./enabled=0/g /etc/yum/pluginconf.d/subscription-manager.conf

RUN yum upgrade -y \
    && dnf install -y 'dnf-command(config-manager)'
RUN yum config-manager --add-repo http://packages.dev.3sca.net/dev_packages_3sca_net.repo
RUN dnf --disablerepo=epel install -y luarocks
RUN yum install -y rpm-build redhat-rpm-config

RUN yum localinstall -y https://rpmfind.net/linux/centos/8-stream/AppStream/x86_64/os/Packages/rpmdevtools-8.10-8.el8.noarch.rpm

RUN mkdir -p /root/rpmbuild/SOURCES/


COPY . /opt/data/
RUN cp /opt/data/licenses.xml /root/rpmbuild/SOURCES/
RUN cp /opt/data/*.rock /root/rpmbuild/SOURCES/
# RUN rm /root/rpmbuild/SOURCES/lua-rover-scm-1.src.rock
RUN spectool -g -R /opt/data/*.spec
RUN rpmbuild -ba /opt/data/*.spec
RUN rpm -i /root/rpmbuild/RPMS/noarch/*.rpm
