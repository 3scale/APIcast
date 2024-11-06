# Build process and components

APIcast is an application based on [OpenResty](https://openresty.org/en/). APIcast consists of two parts: NGINX configuration and Lua files.

## Release

APIcast is released as [Docker image](https://docs.docker.com/engine/tutorials/dockerimages/). 

## Dependencies

APIcast uses LuaRocks, the package manager for Lua modules, to install dependencies. With a correct configuration, LuaRocks installs dependencies into the correct path where OpenResty can see them. 

For Docker images, LuaRocks is installed into the application folder. Then, `luarocks path` adds the application folder to the load path.

Lua Dependencies are defined in [`apicast-VERSION.rockspec`](https://github.com/3scale/apicast/blob/50daf279b3cf2da80b20ad473ec820d7a364b688/apicast-0.1-0.rockspec) file.

* `lua-resty-http` cosocket based http client to be used instead of the `ngx.location.capture`
* `inspect` library to pretty print data structures
* `router` used to implement internal APIs

## Components

APIcast is using [docker](https://www.docker.com/) to build the APIcast runtime image.
You must have docker installed and available on your system.

The development image used is based on [UBI](https://developers.redhat.com/products/rhel/ubi).
It builds on heavy OpenShift base images.
In future releases, we will leverage multistage docker files and use a minimal runtime image.

## Build process

**runtime image**

The runtime image build is defined in the `Makefile`. The `make runtime-image` is for the upstream release build.

**development image**

The development image build is defined in the `Makefile`. The `make dev-build` is meant for development.

## Release

The `master` branch is automatically built and pushed on every successful build by CircleCI to [`quay.io/3scale/apicast:master`](https://quay.io/repository/3scale/apicast?tab=tags&tag=master).
