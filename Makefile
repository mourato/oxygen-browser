# Oxygen development workflows.
#
# Builds run in the helium-macos platform checkout, which consumes this
# repository as its `helium-chromium` submodule. Override PLATFORM_DIR if the
# platform checkout lives elsewhere.

PLATFORM_DIR ?= $(abspath $(CURDIR)/../helium-macos)
UPSTREAM_REMOTE ?= upstream
UPSTREAM_BRANCH ?= main

SUBMODULE_DIR := $(PLATFORM_DIR)/helium-chromium
HE = cd "$(PLATFORM_DIR)" && bash -c '. ./dev.sh && he "$$@"' ./dev.sh

.DEFAULT_GOAL := help
.PHONY: help check upstream sync setup refresh build run validate pop push

help: ## List available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

check: ## Validate patch series and build config in this repo
	python3 devutils/check_patch_files.py
	python3 devutils/validate_config.py

upstream: ## Fetch and merge the latest Helium base (upstream/main)
	git fetch $(UPSTREAM_REMOTE)
	git merge --no-edit $(UPSTREAM_REMOTE)/$(UPSTREAM_BRANCH)

sync: ## Point the platform submodule at this repo's HEAD (patches must be unmerged)
	@test ! -f "$(PLATFORM_DIR)/patches/series.merged" || \
		{ echo "patches are merged; run 'make refresh' instead" >&2; exit 1; }
	@test -z "$$(git -C "$(SUBMODULE_DIR)" status --porcelain)" || \
		{ echo "$(SUBMODULE_DIR) has local changes" >&2; exit 1; }
	git -C "$(SUBMODULE_DIR)" fetch --quiet "$(CURDIR)" HEAD
	git -C "$(SUBMODULE_DIR)" checkout --quiet --detach FETCH_HEAD
	@echo "submodule at $$(git -C "$(SUBMODULE_DIR)" rev-parse --short HEAD)"

setup: sync ## First-time platform setup: download sources, apply patches, configure
	$(HE) setup

refresh: ## Re-apply committed patches to the source tree (pop, sync, push)
	-$(HE) pop
	-$(HE) unmerge
	$(MAKE) sync
	$(HE) merge
	$(HE) push

build: ## Build a development binary
	$(HE) build

run: ## Run the development build with a dedicated data dir
	$(HE) run

validate: ## Validate that merged patches apply cleanly to the source tree
	$(HE) validate patches

pop: ## Unapply all patches from the source tree
	$(HE) pop

push: ## Apply all patches to the source tree
	$(HE) push
