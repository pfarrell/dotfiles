#!/usr/bin/env bash

# DOTFILES_DIR and HOME can be overridden via environment variables (used by tests).
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# Derive the $HOME target path for a given *.symlink item.
# Input:  full path like /path/to/dotfiles/topic/name.symlink
# Output: $HOME/.name
derive_target() {
    local item="$1"
    local base
    base=$(basename "$item")
    local name="${base%.symlink}"
    echo "$HOME/.$name"
}

# Find all *.symlink items at exactly depth 2 (topic/*.symlink).
# Does NOT use -L; does not follow symlinks during traversal.
find_symlink_items() {
    find "$DOTFILES_DIR" -mindepth 2 -maxdepth 2 -name "*.symlink"
}

# --- Subcommand dispatch ---

cmd="${1:-}"

case "$cmd" in
    install)
        echo "install: not yet implemented"
        ;;
    uninstall)
        echo "uninstall: not yet implemented"
        ;;
    _test_derive_target)
        derive_target "$2"
        ;;
    *)
        echo "Usage: install.sh [install|uninstall]" >&2
        exit 1
        ;;
esac
