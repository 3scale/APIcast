MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))

.PHONY: build dependencies cache rockspecs

SPEC ?= $(wildcard *.spec)

SOURCES ?= $(HOME)/rpmbuild/SOURCES
ROCKS ?= $(wildcard $(SOURCES)/*.rock)
ROCKSPECS = `cat $(PROJECT_PATH)/rockspecs`

GIT_BRANCH = $(shell git symbolic-ref --short HEAD)
TARGET ?= $(GIT_BRANCH)-candidate
dependencies:
	yum-builddep $(SPEC)

$(SOURCES):
	mkdir -p $(SOURCES)

rockspecs: $(SOURCES)
	rm -rfv tmprocks;
	mkdir -p tmprocks;
	cd tmprocks; for rock in $(ROCKSPECS); do luarocks pack $$rock; done
	cp tmprocks/*.rock $(SOURCES)/
	cp tmprocks/*.rock .
	rm -rfv tmprocks;

download: $(SOURCES)
	spectool -g -R $(SPEC)
	cp licenses.xml $(SOURCES)/

$(ROCKS): $(SOURCES) download

sources: download rockspecs $(ROCKS)
	@# just strip the directory by awk so it contains just the basename
	@md5sum $(sort $(ROCKS)) | awk '{ "basename " $$2 | getline basename; close("basename"); print $$1, "", basename; }' > sources

cache: $(ROCKS) sources
	rhpkg new-sources $(ROCKS)

build: sources
	rpmbuild -ba $(SPEC)
clean:
	rm -rf ~/rpmbuild/ sources $(ROCKS) *.src.rock

test:
	rhpkg --release rhel-7 prep --builddir=$(shell mktemp -d)
	rhpkg --release rhel-7 scratch-build --target=$(TARGET)

brew:
ifneq (,$(findstring private-,$(GIT_BRANCH)))
	$(error can't build from private branch $(GIT_BRANCH))
else
	rhpkg build --target=$(TARGET)
endif
