SHELL := /bin/bash

BOOT_DIR ?= /Volumes/system-boot
BUILD_DIR := build
TEMPLATE_FILE := templates/user-data.tmpl
RENDERED_FILE := $(BUILD_DIR)/user-data
MERGED_FILE := $(BUILD_DIR)/user-data.merged
MERGE_SCRIPT := scripts/merge_user_data.sh
BOOT_USER_DATA := $(BOOT_DIR)/user-data
BOOT_USER_DATA_ORIG := $(BOOT_DIR)/user-data.imager.orig

ifneq (,$(wildcard .env))
include .env
export
endif

.PHONY: render install test clean check-env

check-env:
	@test -n "$$TAILSCALE_AUTH_KEY" || (echo "ERROR: TAILSCALE_AUTH_KEY is required (.env or env var)." >&2; exit 1)

render: check-env
	@mkdir -p "$(BUILD_DIR)"
	@escaped_key=$$(printf '%s' "$$TAILSCALE_AUTH_KEY" | sed -e 's/[\/&]/\\&/g'); \
	sed "s/{{TAILSCALE_AUTH_KEY}}/$$escaped_key/g" "$(TEMPLATE_FILE)" > "$(RENDERED_FILE)"
	@echo "Rendered $(RENDERED_FILE)"

install: render
	@test -d "$(BOOT_DIR)" || (echo "ERROR: BOOT_DIR does not exist: $(BOOT_DIR)" >&2; exit 1)
	@test -f "$(BOOT_USER_DATA)" || (echo "ERROR: $(BOOT_USER_DATA) not found. Write OS image with Raspberry Pi Imager first." >&2; exit 1)
	@mkdir -p "$(BUILD_DIR)"
	@if [ ! -f "$(BOOT_USER_DATA_ORIG)" ]; then \
		cp "$(BOOT_USER_DATA)" "$(BOOT_USER_DATA_ORIG)"; \
		echo "Saved original Imager user-data: $(BOOT_USER_DATA_ORIG)"; \
	fi
	@bash "$(MERGE_SCRIPT)" "$(BOOT_USER_DATA_ORIG)" "$(RENDERED_FILE)" "$(MERGED_FILE)"
	@cp "$(MERGED_FILE)" "$(BOOT_USER_DATA)"
	@echo "Merged $(BOOT_USER_DATA_ORIG) + $(RENDERED_FILE) -> $(BOOT_USER_DATA)"

test:
	@bash tests/test_setup.sh

clean:
	@rm -rf "$(BUILD_DIR)" "tests/.tmp"
