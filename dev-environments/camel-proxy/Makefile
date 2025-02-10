SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec
.DEFAULT_GOAL := gateway
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
WORKDIR := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER ?= $(shell which docker 2> /dev/null || echo "docker")

gateway: ## run gateway configured to access upstream powered with TLS
	@if [ ! -d "$(WORKDIR)/cert" ]; then \
       echo "$(WORKDIR)/cert does not exist! run make certs!"; \
       exit 1; \
  fi
	$(DOCKER) compose -f docker-compose.yml up --attach gateway

$(WORKDIR)/cert:
	mkdir -p cert

ifeq ($(origin USER),environment)
$(WORKDIR)/cert/keystore.jks: USER := $(shell id -u $(USER))
$(WORKDIR)/cert/keystore.jks: GROUP := $(shell id -g $(USER))
endif
$(WORKDIR)/cert/keystore.jks: ## use same JVM version as camel-netty-proxy, currently openjdk 11.0.9
	$(MAKE) $(WORKDIR)/cert -f $(WORKDIR)/Makefile
	$(DOCKER) run -t --rm \
		-v $(WORKDIR)/cert:/tmp/cert \
		--user $(USER):$(GROUP) \
		registry.access.redhat.com/ubi8/openjdk-11:1.21-1.1733300800 \
		keytool -genkeypair -keystore /tmp/cert/keystore.jks -dname "CN=tls.camel.proxy" -keypass changeit -storepass changeit -alias camel -keyalg RSA -ext SAN=dns:tls.camel.proxy
	$(DOCKER) run -t --rm \
		-v $(WORKDIR)/cert:/tmp/cert \
		--user $(USER):$(GROUP) \
		registry.access.redhat.com/ubi8/openjdk-11:1.21-1.1733300800 \
		keytool -list -v -keystore /tmp/cert/keystore.jks -storepass changeit

.PHONY: certs
certs: clean
	$(MAKE) $(WORKDIR)/cert/keystore.jks -f $(WORKDIR)/Makefile

clean:
	$(DOCKER) compose down --volumes --remove-orphans
	$(DOCKER) compose -f docker-compose.yml down --volumes --remove-orphans
	- rm -rf $(WORKDIR)/cert

