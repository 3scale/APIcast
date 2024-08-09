#!/bin/sh
set -x -e -u

user=${SUDO_USER:-${CIRCLECI_USER:-vagrant}}

# CircleCI forces use of SSH protocol everywhere, we need to reset it.
export HOME="/tmp"
export PATH=$PATH:/usr/local/bin

# Clone various utilities
git clone https://github.com/openresty/stapxx.git /usr/local/stapxx || (cd /usr/local/stapxx && git pull)
git clone https://github.com/brendangregg/FlameGraph.git /usr/local/flamegraph || (cd /usr/local/flamegraph && git pull)
git clone https://github.com/openresty/openresty-systemtap-toolkit.git /usr/local/openresty-systemtap-toolkit || (cd /usr/local/openresty-systemtap-toolkit && git pull)
curl -L https://github.com/tsenart/vegeta/releases/download/v6.1.1/vegeta-v6.1.1-linux-amd64.tar.gz | tar -xz --overwrite -C /usr/local/bin/

git clone https://github.com/wg/wrk.git /usr/local/wrk || (cd /usr/local/wrk && git pull)
( cd /usr/local/wrk && make && mv wrk /usr/local/bin/ )

git clone https://github.com/lighttpd/weighttp.git /usr/local/weighttp || (cd /usr/local/weighttp && git pull)
( cd /usr/local/weighttp && gcc -O2 -DPACKAGE_VERSION='"0.4"' src/*.c -o weighttp -lev -lpthread && ln -sf "$(pwd)/weighttp" /usr/local/bin/ )

# Utility to resolve builtin functions
# echo '#!/usr/bin/env luajit' > /usr/local/bin/ljff
# curl -L https://raw.githubusercontent.com/openresty/openresty-devel-utils/master/ljff.lua >> /usr/local/bin/ljff
# chmod +x /usr/local/bin/ljff

# Create stap++ executable always pointing to its proper location
echo '#!/bin/sh' > /usr/local/bin/stap++
echo 'exec /usr/local/stapxx/stap++ -I /usr/local/stapxx/tapset "$@"' >> /usr/local/bin/stap++
chmod +x /usr/local/bin/stap++

# shellcheck disable=SC2016
echo 'export PATH="lua_modules/bin:${PATH}"' > /etc/profile.d/rover.sh
chmod +x /etc/profile.d/rover.sh

# shellcheck disable=SC2016
echo 'eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)' > /etc/profile.d/perl.sh
chmod +x /etc/profile.d/perl.sh

if [ -n "${CIRCLE_SHELL_ENV:-}" ]; then
    cat /etc/profile.d/rover.sh >> "${CIRCLE_SHELL_ENV}"
    cat /etc/profile.d/perl.sh >> "${CIRCLE_SHELL_ENV}"
fi

# Add various utilites to the PATH
ln -sf /usr/local/openresty/luajit/bin/luajit /usr/local/bin/luajit
ln -sf /usr/local/flamegraph/*.pl /usr/local/bin/
ln -sf /usr/local/stapxx/samples/*.sxx /usr/local/bin/
# shellcheck disable=SC2046
ln -sf $(find /usr/local/openresty-systemtap-toolkit/ -maxdepth 1 -type f -executable -print) /usr/local/bin/

# Allow vagrant user to use systemtap
usermod -aG stapusr,stapdev "${user}"

# Raise opened files limit for vagrant user
# shellcheck disable=SC1117
printf "%b${user}\t\t\t-\tnofile\t\t1000000" > /etc/security/limits.d/90-nofile.conf

echo 'kernel.perf_event_paranoid = -1' > /etc/sysctl.d/perf.conf
# shellcheck disable=SC2039
echo "-1" > /proc/sys/kernel/perf_event_paranoid
