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

# Back up $1 to $1.backup.
# Returns 0 on success, 1 if backup already exists (prints warning).
backup_path() {
    local path="$1"
    local backup="${path}.backup"
    if [[ -e "$backup" || -L "$backup" ]]; then
        echo "WARNING: $backup already exists, skipping $path" >&2
        return 1
    fi
    mv "$path" "$backup"
}

# Install a single *.symlink item.
# Returns 0 on success, 1 on error.
install_item() {
    local item="$1"
    local target
    target=$(derive_target "$item")

    # Idempotency: already correctly linked
    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$item" ]]; then
        echo "  skipping $target (already linked)"
        return 0
    fi

    # Target exists but is wrong: back it up
    if [[ -e "$target" || -L "$target" ]]; then
        if ! backup_path "$target"; then
            return 1
        fi
        echo "  backed up $target -> ${target}.backup"
    fi

    if ln -s "$item" "$target"; then
        echo "  linked $target -> $item"
        return 0
    else
        echo "ERROR: failed to create symlink $target -> $item" >&2
        return 1
    fi
}

do_install() {
    local errors=0

    # Step 1: create ~/.dotfiles -> $DOTFILES_DIR
    local dotfiles_link="$HOME/.dotfiles"
    if [[ -L "$dotfiles_link" ]] && [[ "$(readlink "$dotfiles_link")" == "$DOTFILES_DIR" ]]; then
        echo "  skipping $dotfiles_link (already linked)"
    elif [[ -e "$dotfiles_link" || -L "$dotfiles_link" ]]; then
        if backup_path "$dotfiles_link"; then
            echo "  backed up $dotfiles_link -> ${dotfiles_link}.backup"
            ln -s "$DOTFILES_DIR" "$dotfiles_link" && echo "  linked $dotfiles_link -> $DOTFILES_DIR" || ((errors++))
        else
            ((errors++))
        fi
    else
        ln -s "$DOTFILES_DIR" "$dotfiles_link" && echo "  linked $dotfiles_link -> $DOTFILES_DIR" || ((errors++))
    fi

    # Step 2: install each *.symlink item
    while IFS= read -r item; do
        install_item "$item" || ((errors++))
    done < <(find_symlink_items)

    return $errors
}

# --- Subcommand dispatch ---

cmd="${1:-}"

case "$cmd" in
    install)
        do_install
        exit $?
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
