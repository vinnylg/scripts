# ============================
# Configuration
# ============================

SHELL := /bin/bash
BIN_DIR := bin
LIB_DIR := lib
TEST_DIR := test
COMPLETIONS_DIR := completions

# Tools (placeholders)
SHELLCHECK ?= shellcheck
BATS ?= bats

# ============================
# Targets
# ============================

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make lint        Run shellcheck"
	@echo "  make test        Run test suite"
	@echo "  make check       Lint + test"
	@echo "  make install     Install scripts (symlink or copy)"
	@echo "  make uninstall   Remove installed scripts"

# ----------------------------

.PHONY: lint
lint:
	$(SHELLCHECK) $(BIN_DIR)/* $(LIB_DIR)/**/*.sh

# ----------------------------

.PHONY: test
test:
	$(BATS) $(TEST_DIR)

# ----------------------------

.PHONY: check
check: lint test

# ----------------------------

.PHONY: install
install:
	@echo "TODO: implement install logic"
	@echo "Suggested: symlink bin/* to ~/.local/bin"

# ----------------------------

.PHONY: uninstall
uninstall:
	@echo "TODO: implement uninstall logic"

