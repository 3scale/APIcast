package = "apicast"
version = "scm-1"
source = {
   url = "git+https://github.com/3scale/apicast.git",
   branch = 'master'
}
description = {
   detailed = "3scale API Gateway",
   homepage = "https://github.com/3scale/apicast",
   license = "Apache License 2.0"
}
dependencies = {
   'lua-resty-http == 0.17.1',
   'inspect',
   'lyaml',
   'router',
   'lua-resty-jwt == 0.2.4',
   'lua-resty-url',
   'lua-resty-env',
   'lua-resty-execvp',
   'liquid == 0.2.1',
   'argparse',
   'penlight == 1.15.0',
   'nginx-lua-prometheus == 0.20181120',
   'lua-resty-jit-uuid',
   'lua-resty-ipmatcher',
   'lua-resty-openssl == 1.7.1'
}
build = {
   type = "make",
   makefile = 'gateway/Makefile',
   build_pass = false,
   build_variables = {
      CFLAGS='$(CFLAGS)'
   },
   install_variables = {
      INST_PREFIX="$(PREFIX)",
      INST_BINDIR="$(BINDIR)",
      INST_LIBDIR="$(LIBDIR)",
      INST_LUADIR="$(LUADIR)",
      INST_CONFDIR="$(CONFDIR)",
   },
}
