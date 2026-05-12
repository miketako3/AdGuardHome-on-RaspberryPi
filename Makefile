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
	@test -n "$$ADGUARD_ADMIN_USER" || (echo "ERROR: ADGUARD_ADMIN_USER is required (.env or env var)." >&2; exit 1)
	@test -n "$$ADGUARD_ADMIN_PASSWORD" || (echo "ERROR: ADGUARD_ADMIN_PASSWORD is required (.env or env var)." >&2; exit 1)
	@test -n "$$ADGUARD_DNS_BIND_HOST" || (echo "ERROR: ADGUARD_DNS_BIND_HOST is required (.env or env var)." >&2; exit 1)
	@command -v htpasswd >/dev/null 2>&1 || (echo "ERROR: htpasswd is required (install apache2-utils)." >&2; exit 1)

render: check-env
	@mkdir -p "$(BUILD_DIR)"
	@adguard_password_hash=$$(printf '%s\n' "$$ADGUARD_ADMIN_PASSWORD" | htpasswd -niBC 10 "$$ADGUARD_ADMIN_USER" | cut -d: -f2-); \
	escaped_key="$$TAILSCALE_AUTH_KEY"; \
	escaped_user="$$ADGUARD_ADMIN_USER"; \
	escaped_bind_host="$$ADGUARD_DNS_BIND_HOST"; \
	escaped_password_hash="$$adguard_password_hash"; \
	escaped_key=$${escaped_key//\\/\\\\}; \
	escaped_key=$${escaped_key//&/\\&}; \
	escaped_key=$${escaped_key//|/\\|}; \
	escaped_user=$${escaped_user//\\/\\\\}; \
	escaped_user=$${escaped_user//&/\\&}; \
	escaped_user=$${escaped_user//|/\\|}; \
	escaped_bind_host=$${escaped_bind_host//\\/\\\\}; \
	escaped_bind_host=$${escaped_bind_host//&/\\&}; \
	escaped_bind_host=$${escaped_bind_host//|/\\|}; \
	escaped_password_hash=$${escaped_password_hash//\\/\\\\}; \
	escaped_password_hash=$${escaped_password_hash//&/\\&}; \
	escaped_password_hash=$${escaped_password_hash//|/\\|}; \
	sed \
		-e "s|{{TAILSCALE_AUTH_KEY}}|$$escaped_key|g" \
		-e "s|{{ADGUARD_ADMIN_USER}}|$$escaped_user|g" \
		-e "s|{{ADGUARD_DNS_BIND_HOST}}|$$escaped_bind_host|g" \
		-e "s|{{ADGUARD_ADMIN_PASSWORD_HASH}}|$$escaped_password_hash|g" \
		"$(TEMPLATE_FILE)" > "$(RENDERED_FILE)"
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
