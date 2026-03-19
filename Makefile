.PHONY: install uninstall test help

help:
	@echo "install   - symlink dotfiles into home directory"
	@echo "uninstall - remove symlinks and restore backups"
	@echo "test      - run the test suite"

install:
	@bash scripts/install.sh install

uninstall:
	@bash scripts/install.sh uninstall

test:
	@bash scripts/test_install.sh

.DEFAULT_GOAL := install
