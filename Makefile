SHELL := /bin/bash

BOOT_DIR ?= /Volumes/system-boot
BUILD_DIR := build
TEMPLATE_FILE := templates/user-data.tmpl
RENDERED_FILE := $(BUILD_DIR)/user-data

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
	@cp "$(RENDERED_FILE)" "$(BOOT_DIR)/user-data"
	@echo "Copied $(RENDERED_FILE) -> $(BOOT_DIR)/user-data"

test:
	@bash tests/test_setup.sh

clean:
	@rm -rf "$(BUILD_DIR)" "tests/.tmp"
