# Trace scripts

A few trace scripts to run bpftrace tool in the container and be able to debug
how Nginx behave

## Install

```shell
docker exec -ti --user root --privileged apicast_build_0_development_1 dnf install -y bpftrace
```

Recommended to install debuginfo packages to get better ustack

```
docker exec -ti --user root --privileged apicast_build_0_development_1 dnf install -y openresty-debuginfo
```


## Run

```shell
docker exec -ti --user root --privileged apicast_build_0_development_1 bpftrace leaked.bt -p ${OPENRESTY_WORKER_PID}
```
