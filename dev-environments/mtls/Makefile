SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec
.DEFAULT_GOAL := gateway
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
WORKDIR := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER ?= $(shell which docker 2> /dev/null || echo "docker")

gateway: ## run gateway configured to access upstream powered with TLS
	$(DOCKER) compose -f docker-compose.yml up --attach gateway

clean:
	$(DOCKER) compose down --volumes --remove-orphans
	$(DOCKER) compose -f docker-compose.yml down --volumes --remove-orphans
	$(MAKE) clean -C $(WORKDIR)/cert -f $(WORKDIR)/cert/Makefile

certs:
	$(MAKE) clean -C $(WORKDIR)/cert -f $(WORKDIR)/cert/Makefile
	$(MAKE) all -C $(WORKDIR)/cert -f $(WORKDIR)/cert/Makefile

template: export WHITELIST=$(shell cat cert/intermediate.cert.pem | tr '\n' ' ')
template: export CRL=$(shell cat cert/intermediate.crl.pem | tr '\n' ' ')
template:
	yq -i '.services[0].proxy.policy_chain[0].configuration.whitelist[0].pem_certificate="$(WHITELIST)"' apicast-config.json
	yq -i '.services[0].proxy.policy_chain[0].configuration.revoke_list[0].pem_certificate="$(CRL)"' apicast-config.json
	yq -i '.services[1].proxy.policy_chain[0].configuration.whitelist[0].pem_certificate="$(WHITELIST)"' apicast-config.json

