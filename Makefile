SHELL := /usr/bin/env bash

.PHONY: check install-base setup-session setup-session-system build-iso

check:
	bash scripts/check.sh

install-base:
	sudo bash scripts/install_base.sh

setup-session:
	bash scripts/setup_session.sh

setup-session-system:
	bash scripts/setup_session.sh --system

build-iso:
	sudo bash scripts/build_iso.sh
