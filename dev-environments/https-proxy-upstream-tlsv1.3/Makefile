SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec
.DEFAULT_GOAL := gateway
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
WORKDIR := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER ?= $(shell which docker 2> /dev/null || echo "docker")

gateway: ## run gateway configured to access upstream powered with TLS
	$(DOCKER) compose -f docker-compose.yml up

clean:
	$(DOCKER) compose down --volumes --remove-orphans
	$(DOCKER) compose -f docker-compose.yml down --volumes --remove-orphans

certs:
	$(MAKE) clean -C $(WORKDIR)/cert -f $(WORKDIR)/cert/Makefile
	$(MAKE) ca -C $(WORKDIR)/cert -f $(WORKDIR)/cert/Makefile
	$(MAKE) clientcerts -C $(WORKDIR)/cert -f $(WORKDIR)/cert/Makefile DOMAIN=example.com
