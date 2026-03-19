#!/usr/bin/env bash
# Test harness for scripts/install.sh
# Uses temp directories to isolate tests from the real home directory.

# Counter file for cross-subshell pass/fail tracking
COUNTER_FILE=$(mktemp)
echo "0 0" > "$COUNTER_FILE"
FAILURES_FILE=$(mktemp)
trap 'rm -f "$COUNTER_FILE" "$FAILURES_FILE"' EXIT

_increment_pass() {
    local pass fail
    read -r pass fail < "$COUNTER_FILE"
    echo "$((pass + 1)) $fail" > "$COUNTER_FILE"
}

_increment_fail() {
    local msg="$1"
    local pass fail
    read -r pass fail < "$COUNTER_FILE"
    echo "$pass $((fail + 1))" > "$COUNTER_FILE"
    echo "  - $msg" >> "$FAILURES_FILE"
}

# --- Harness helpers ---

assert_equals() {
    local expected="$1" actual="$2" msg="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: $msg"
        _increment_pass
    else
        echo "  FAIL: $msg"
        echo "    expected: $(printf '%q' "$expected")"
        echo "    actual:   $(printf '%q' "$actual")"
        _increment_fail "$msg"
    fi
}

assert_symlink_target() {
    local expected_target="$1" link_path="$2" msg="$3"
    local actual
    actual=$(readlink "$link_path" 2>/dev/null)
    assert_equals "$expected_target" "$actual" "$msg"
}

assert_path_exists() {
    local path="$1" msg="$2"
    if [[ -e "$path" || -L "$path" ]]; then
        echo "  PASS: $msg"
        _increment_pass
    else
        echo "  FAIL: $msg (path does not exist: $path)"
        _increment_fail "$msg"
    fi
}

assert_path_not_exists() {
    local path="$1" msg="$2"
    if [[ ! -e "$path" && ! -L "$path" ]]; then
        echo "  PASS: $msg"
        _increment_pass
    else
        echo "  FAIL: $msg (path unexpectedly exists: $path)"
        _increment_fail "$msg"
    fi
}

run_test() {
    local name="$1"
    shift
    echo ""
    echo "TEST: $name"
    (
        local tmp_home tmp_dotfiles
        tmp_home=$(mktemp -d)
        tmp_dotfiles=$(mktemp -d)
        trap 'rm -rf "$tmp_home" "$tmp_dotfiles"' EXIT
        TMP_HOME="$tmp_home" TMP_DOTFILES="$tmp_dotfiles" "$@"
    )
}

run_installer() {
    local subcmd="$1"
    HOME="$TMP_HOME" DOTFILES_DIR="$TMP_DOTFILES" bash "$(dirname "$0")/install.sh" "$subcmd"
}

# --- Test runner ---

echo "Running dotfiles installer tests..."

# --- Name derivation tests ---

test_derive_target_from_file() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bash_profile.symlink"

    local output
    output=$(HOME="$TMP_HOME" DOTFILES_DIR="$TMP_DOTFILES" bash "$(dirname "$0")/install.sh" _test_derive_target "$TMP_DOTFILES/bash/bash_profile.symlink")
    assert_equals "$TMP_HOME/.bash_profile" "$output" "file: derives correct target path"
}

test_derive_target_from_directory() {
    mkdir -p "$TMP_DOTFILES/vim/vim.symlink"

    local output
    output=$(HOME="$TMP_HOME" DOTFILES_DIR="$TMP_DOTFILES" bash "$(dirname "$0")/install.sh" _test_derive_target "$TMP_DOTFILES/vim/vim.symlink")
    assert_equals "$TMP_HOME/.vim" "$output" "directory: derives correct target path"
}

run_test "derive target - file" test_derive_target_from_file
run_test "derive target - directory" test_derive_target_from_directory

# --- Install: happy path ---

test_install_creates_file_symlink() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"

    run_installer install

    assert_symlink_target "$TMP_DOTFILES/bash/bashrc.symlink" "$TMP_HOME/.bashrc" \
        "install: creates file symlink"
}

test_install_creates_directory_symlink() {
    mkdir -p "$TMP_DOTFILES/vim/vim.symlink"
    touch "$TMP_DOTFILES/vim/vim.symlink/vimrc"

    run_installer install

    assert_symlink_target "$TMP_DOTFILES/vim/vim.symlink" "$TMP_HOME/.vim" \
        "install: creates directory symlink"
}

test_install_creates_dotfiles_symlink() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"

    run_installer install

    assert_symlink_target "$TMP_DOTFILES" "$TMP_HOME/.dotfiles" \
        "install: creates ~/.dotfiles symlink"
}

test_install_idempotent() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"

    run_installer install
    run_installer install  # second run

    assert_symlink_target "$TMP_DOTFILES/bash/bashrc.symlink" "$TMP_HOME/.bashrc" \
        "install: idempotent — symlink unchanged after second install"
    assert_path_not_exists "$TMP_HOME/.bashrc.backup" \
        "install: idempotent — no spurious backup created"
}

run_test "install - creates file symlink" test_install_creates_file_symlink
run_test "install - creates directory symlink" test_install_creates_directory_symlink
run_test "install - creates ~/.dotfiles symlink" test_install_creates_dotfiles_symlink
run_test "install - idempotent" test_install_idempotent

# --- Install: conflict handling ---

test_install_backs_up_existing_file() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"
    echo "original content" > "$TMP_HOME/.bashrc"

    run_installer install

    assert_symlink_target "$TMP_DOTFILES/bash/bashrc.symlink" "$TMP_HOME/.bashrc" \
        "conflict: symlink created after backup"
    assert_path_exists "$TMP_HOME/.bashrc.backup" \
        "conflict: original file backed up"
    assert_equals "original content" "$(cat "$TMP_HOME/.bashrc.backup")" \
        "conflict: backup contains original content"
}

test_install_backs_up_existing_directory() {
    mkdir -p "$TMP_DOTFILES/vim/vim.symlink"
    mkdir -p "$TMP_HOME/.vim/autoload"

    run_installer install

    assert_symlink_target "$TMP_DOTFILES/vim/vim.symlink" "$TMP_HOME/.vim" \
        "conflict dir: symlink created after backup"
    assert_path_exists "$TMP_HOME/.vim.backup" \
        "conflict dir: original directory backed up"
    assert_path_exists "$TMP_HOME/.vim.backup/autoload" \
        "conflict dir: backup contains original directory contents"
}

test_install_skips_when_backup_already_exists() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"
    echo "original" > "$TMP_HOME/.bashrc"
    echo "prior backup" > "$TMP_HOME/.bashrc.backup"

    local output
    output=$(run_installer install 2>&1)

    assert_path_not_exists "$TMP_HOME/.bashrc.backup.backup" \
        "skip: no new backup created when backup exists"
    # The symlink should NOT have been created (item was skipped)
    local target_is_symlink=false
    [[ -L "$TMP_HOME/.bashrc" ]] && target_is_symlink=true
    assert_equals "false" "$target_is_symlink" \
        "skip: symlink not created when backup already exists"
    assert_equals "prior backup" "$(cat "$TMP_HOME/.bashrc.backup")" \
        "skip: existing backup not overwritten"
}

run_test "install - backs up existing file" test_install_backs_up_existing_file
run_test "install - backs up existing directory" test_install_backs_up_existing_directory
run_test "install - skips when backup already exists" test_install_skips_when_backup_already_exists

# --- Results ---

echo ""
read -r PASS FAIL < "$COUNTER_FILE"
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    echo "Failed tests:"
    cat "$FAILURES_FILE"
    exit 1
fi
exit 0
