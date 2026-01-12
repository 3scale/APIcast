MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec
.DEFAULT_GOAL := help

DOCKER ?= $(shell which docker 2> /dev/null || echo "docker")
REGISTRY ?= quay.io/3scale
export TEST_NGINX_BINARY ?= openresty
NGINX = $(shell which $(TEST_NGINX_BINARY))

NPROC ?= $(firstword $(shell nproc 2>/dev/null) 1)

SEPARATOR="\n=============================================\n"

DEVEL_IMAGE ?= quay.io/3scale/apicast-ci:openresty-1.21.4-4
DEVEL_DOCKERFILE ?= Dockerfile.devel

RUNTIME_IMAGE ?= quay.io/3scale/apicast:latest

DEVEL_DOCKER_COMPOSE_FILE ?= docker-compose-devel.yml
DEVEL_DOCKER_COMPOSE_VOLMOUNT_MAC_FILE ?= docker-compose-devel-volmount-mac.yml
DEVEL_DOCKER_COMPOSE_VOLMOUNT_DEFAULT_FILE ?= docker-compose-devel-volmount-default.yml

PROVE_DOCKER_COMPOSE_FILE ?= docker-compose.prove.yml

DOCKER_VOLUME_NAME ?= apicast-local-volume

os = "$(shell uname -s)"

# if running on Mac
ifeq ($(os),"Darwin")
    DEVEL_DOCKER_COMPOSE_VOLMOUNT_FILE = $(DEVEL_DOCKER_COMPOSE_VOLMOUNT_MAC_FILE)
else
    DEVEL_DOCKER_COMPOSE_VOLMOUNT_FILE = $(DEVEL_DOCKER_COMPOSE_VOLMOUNT_DEFAULT_FILE)
endif

GATEWAY_CONTEXT ?= $(PROJECT_PATH)/gateway

GIT_TAG += $(CIRCLE_TAG)
GIT_TAG += $(shell git describe --tags --exact-match 2>/dev/null)

GIT_BRANCH += $(CIRCLE_BRANCH)
GIT_BRANCH += $(shell git symbolic-ref --short HEAD 2>/dev/null)

CIRCLE_NODE_INDEX ?= 0
CIRCLE_STAGE ?= build
COMPOSE_PROJECT_NAME ?= apicast_$(CIRCLE_STAGE)_$(CIRCLE_NODE_INDEX)

which = $(shell command -v $(1) 2> /dev/null)

ROVER ?= $(call which, rover)
ifeq ($(ROVER),)
ROVER := lua_modules/bin/rover
endif

CPANM ?= $(call which, cpanm)
CARTON ?= $(firstword $(call which, carton) local/bin/carton)

export COMPOSE_PROJECT_NAME

.PHONY: benchmark lua_modules

# The development image is also used in CI (circleCI) as the 'openresty' executor
# When the development image changes, make sure to:
# * build a new development image:
#     make dev-build IMAGE_NAME=quay.io/3scale/apicast-ci:openresty-X.Y.Z-{release_number}
# * push to quay.io/3scale/apicast-ci with a fixed tag (avoid floating tags)
#     docker push quay.io/3scale/apicast-ci:openresty-X.Y.Z-{release_number}
# * update .circleci/config.yaml openresty executor with the image URL
.PHONY: dev-build
dev-build: export OPENRESTY_RPM_VERSION?=1.21.4
dev-build: export LUAROCKS_VERSION?=3.12.0
dev-build: IMAGE_NAME ?= apicast-development:latest
dev-build: ## Build development image
	$(DOCKER) build --platform linux/amd64 -t $(IMAGE_NAME) \
		--build-arg OPENRESTY_RPM_VERSION=$(OPENRESTY_RPM_VERSION) \
		--build-arg LUAROCKS_VERSION=$(LUAROCKS_VERSION) \
		$(PROJECT_PATH) -f $(DEVEL_DOCKERFILE)

test: ## Run all tests
	$(MAKE) --keep-going busted prove dev-build prove-docker runtime-image test-runtime-image

apicast-source: export IMAGE_NAME ?= $(DEVEL_IMAGE)
apicast-source: ## Create Docker Volume container with APIcast source code
	($(DOCKER) volume inspect $(DOCKER_VOLUME_NAME) 1>/dev/null 2>&1 && \
		$(DOCKER) volume rm $(DOCKER_VOLUME_NAME) 1>/dev/null ) || true
	$(DOCKER) volume create $(DOCKER_VOLUME_NAME) 1>/dev/null
	$(DOCKER) rm dummy 1>/dev/null 2>&1 || true
	$(DOCKER) run -d --rm --name dummy -v $(DOCKER_VOLUME_NAME):/opt/app-root/src alpine tail -f /dev/null
	$(DOCKER) cp . dummy:/opt/app-root/src
	$(DOCKER) exec --user root dummy \
		chown -R $(shell $(DOCKER) run --rm $(IMAGE_NAME) /bin/bash -c 'id -u'):$(shell $(DOCKER) run --rm $(IMAGE_NAME) /bin/bash -c 'id -g') \
		/opt/app-root/src
	$(DOCKER) stop dummy

nginx:
	@ ($(NGINX) -V 2>&1) > /dev/null

$(CPANM):
ifeq ($(CPANM),)
	$(error Missing cpanminus. Install it by running `curl -L https://cpanmin.us | perl - App::cpanminus`)
endif

local/bin/carton: $(CPANM)
	$(CPANM) --local-lib ./local --notest Carton

cpan: $(CPANM)
	$(CPANM) --local-lib ./local --notest --installdeps ./gateway

PERL5LIB:=$(PWD)/local/lib/perl5:$(PERL5LIB)
export PERL5LIB

CPANFILE ?= $(PWD)/gateway/cpanfile

$(CPANFILE).snapshot : $(CPANFILE)
	$(CARTON) install --cached

carton: export PERL_CARTON_CPANFILE=$(CPANFILE)
carton: export PERL_CARTON_PATH=$(PWD)/local
carton: $(CARTON) $(CPANFILE).snapshot
carton:
	$(CARTON) install --deployment --cached
	$(CARTON) bundle 2> /dev/null

circleci = $(shell circleci tests glob $(1) 2>/dev/null | grep -v examples/scaffold | circleci tests split --split-by=timings 2>/dev/null)

BUSTED_PATTERN = "{spec,examples}/**/*_spec.lua"
BUSTED_FILES ?= $(call circleci, $(BUSTED_PATTERN))
busted: $(ROVER) lua_modules ## Test Lua.
	$(ROVER) exec bin/busted $(BUSTED_FILES) $(BUSTED_ARGS)
ifeq ($(CI),true)
	@- luacov
endif

PROVE_PATTERN = "{t,examples}/**/*.t"

prove: HARNESS ?= TAP::Harness
prove: PROVE_FILES ?= $(call circleci, $(PROVE_PATTERN))
prove: export TEST_NGINX_RANDOMIZE=1
prove: $(ROVER) dependencies nginx ## Test nginx
	$(ROVER) exec script/prove --verbose -j$(NPROC) --harness=$(HARNESS) $(PROVE_FILES)

prove-docker: export IMAGE_NAME ?= $(DEVEL_IMAGE)
prove-docker: ## Test nginx inside docker
	make -C $(PROJECT_PATH) -f $(MKFILE_PATH) apicast-source
	$(DOCKER) compose -f $(PROVE_DOCKER_COMPOSE_FILE) run --rm -T \
		-v $(DOCKER_VOLUME_NAME):/opt/app-root/src prove | \
		awk '/Result: NOTESTS/ { print "FAIL: NOTESTS"; print; exit 1 }; { print }'

runtime-image: IMAGE_NAME ?= apicast-runtime-image:latest
runtime-image: ## Build runtime image
	$(DOCKER) build -t $(IMAGE_NAME) $(PROJECT_PATH)

push: ## Push image to the registry
	docker tag $(IMAGE_NAME) $(REGISTRY)/$(IMAGE_NAME)
	docker push $(REGISTRY)/$(IMAGE_NAME)

bash: export IMAGE_NAME ?= $(RUNTIME_IMAGE)
bash: export SERVICE = gateway
bash: ## Run bash inside the runtime image
	$(DOCKER) compose run --user=root --rm --entrypoint=bash $(SERVICE)

gateway-logs: export IMAGE_NAME = does-not-matter
gateway-logs:
	$(DOCKER) compose logs gateway

test-runtime-image: export IMAGE_NAME ?= $(RUNTIME_IMAGE)
test-runtime-image: clean-containers ## Smoke test the runtime image. Pass any docker image in IMAGE_NAME parameter.
	$(DOCKER) compose --version
	$(DOCKER) compose run --rm --user 100001 gateway apicast -l -d
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm --user 100002 -e APICAST_CONFIGURATION_LOADER=boot -e THREESCALE_PORTAL_ENDPOINT=https://echo-api.3scale.net gateway bin/apicast -d
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm test sh -c 'sleep 5 && curl --fail http://gateway:8090/status/live'
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm --user 100001 gateway bin/apicast --test
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm --user 100001 gateway bin/apicast --test --dev
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm --user 100001 gateway bin/apicast --daemon
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm test bash -c 'for i in {1..5}; do curl --fail http://gateway:8090/status/live && break || sleep 1; done'
	$(DOCKER) compose logs gateway
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm test curl --fail -X PUT http://gateway:8090/config --data '{"services":[{"id":42}]}'
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm test curl --fail http://gateway:8090/status/ready
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm test curl --fail -X POST http://gateway:8090/boot
	@echo -e $(SEPARATOR)
	$(DOCKER) compose run --rm gateway bin/apicast -c http://echo-api.3scale.net -d -b

$(PROJECT_PATH)/lua_modules $(PROJECT_PATH)/local $(PROJECT_PATH)/.cpanm $(PROJECT_PATH)/vendor/cache $(PROJECT_PATH)/.cache :
	mkdir -p $@

dep_folders: $(PROJECT_PATH)/lua_modules $(PROJECT_PATH)/local $(PROJECT_PATH)/.cpanm $(PROJECT_PATH)/vendor/cache $(PROJECT_PATH)/.cache

ifeq ($(origin USER),environment)
development: USER := $(shell id -u $(USER))
development: GROUP := $(shell id -g $(USER))
endif
development: ## Run bash inside the development image
	@echo "Running on $(os)"
	- $(DOCKER) compose -f $(DEVEL_DOCKER_COMPOSE_FILE) -f $(DEVEL_DOCKER_COMPOSE_VOLMOUNT_FILE) up -d
	@ # https://github.com/moby/moby/issues/33794#issuecomment-312873988 for fixing the terminal width
	$(DOCKER) compose -f $(DEVEL_DOCKER_COMPOSE_FILE) -f $(DEVEL_DOCKER_COMPOSE_VOLMOUNT_FILE) exec -e COLUMNS="`tput cols`" -e LINES="`tput lines`" --user $(USER):$(GROUP) development bash

stop-development: clean-containers ## Stop development environment

rover: $(ROVER)
	@echo $(ROVER)

$(GATEWAY_CONTEXT)/Roverfile.lock : $(GATEWAY_CONTEXT)/Roverfile $(GATEWAY_CONTEXT)/apicast-scm-1.rockspec
	$(ROVER) lock --roverfile=$(GATEWAY_CONTEXT)/Roverfile

translate_git_protocol:
	@git config --global url.https://github.com/.insteadOf git://github.com/

lua_modules: $(ROVER) translate_git_protocol $(GATEWAY_CONTEXT)/Roverfile.lock
# This variable is to skip issues with openssl 1.1.1
# https://github.com/wahern/luaossl/issues/175
	EXTRA_CFLAGS="-DHAVE_EVP_KDF_CTX=1" $(ROVER) install --roverfile=$(GATEWAY_CONTEXT)/Roverfile > /dev/null

lua_modules/bin/rover:
	@LUAROCKS_CONFIG=$(GATEWAY_CONTEXT)/config-5.1.lua luarocks install --server=http://luarocks.org/dev lua-rover --tree=lua_modules 1>&2

dependencies: dep_folders lua_modules carton  ## Install project dependencies

clean-containers:
	$(DOCKER) compose down --volumes --remove-orphans
	$(DOCKER) compose -f $(PROVE_DOCKER_COMPOSE_FILE) down --volumes --remove-orphans
	$(DOCKER) compose -f $(DEVEL_DOCKER_COMPOSE_FILE) -f $(DEVEL_DOCKER_COMPOSE_VOLMOUNT_FILE) down --volumes --remove-orphans

clean-deps: ## Remove all local dependency folders
	- rm -rf $(PROJECT_PATH)/lua_modules $(PROJECT_PATH)/local $(PROJECT_PATH)/.cpanm $(PROJECT_PATH)/vendor/cache $(PROJECT_PATH)/.cache :

clean: ## Remove all docker containers and images
	make -C $(PROJECT_PATH) -f $(MKFILE_PATH) clean-containers
	- docker rmi $(DEVEL_IMAGE) $(RUNTIME_IMAGE) apicast-runtime-image:latest apicast-development:latest --force
	- rm -rf luacov.stats*.out
	- rm -rf $(PROJECT_PATH)/t/servroot_*
	make -C $(PROJECT_PATH) -f $(MKFILE_PATH) clean-deps

doc/lua/index.html: $(shell find gateway/src -name '*.lua' 2>/dev/null) | lua_modules $(ROVER)
	$(ROVER) exec ldoc -c doc/config.ld .

doc: doc/lua/index.html ## Generate documentation

lint-schema:
	@ docker run --volumes-from ${COMPOSE_PROJECT_NAME}-source --workdir /opt/app-root/src \
		3scale/ajv validate \
		-s gateway/src/apicast/policy/manifest-schema.json \
		$(addprefix -d ,$(shell find gateway/src/apicast/policy -name 'apicast-policy.json'))

node_modules/.bin/markdown-link-check:
	yarn install

test-doc: node_modules/.bin/markdown-link-check
	@find . -type d \( -path ./node_modules -o -path ./.git -o -path ./t -o -path ./.github \) -prune -o -name "*.md" -print0 | xargs -0 -n1  -I % sh -c 'node_modules/.bin/markdown-link-check -v --config markdown-lint-check-config.json  %' \;

benchmark: export IMAGE_TAG ?= master
benchmark: export COMPOSE_FILE ?= docker-compose.benchmark.yml
benchmark: export COMPOSE_PROJECT_NAME = apicast-benchmark
benchmark: export WRK_REPORT ?= $(IMAGE_TAG).csv
benchmark: export DURATION ?= 300
benchmark:
	- $(DOCKER) compose up --force-recreate -d apicast
	$(DOCKER) compose run curl
	## warmup round for $(DURATION)/10 seconds
	DURATION=$$(( $(DURATION) / 10 )) $(DOCKER) compose run wrk
	## run the real benchmark for $(DURATION) seconds
	$(DOCKER) compose run wrk

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
