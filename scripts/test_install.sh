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

# --- Uninstall ---

test_uninstall_removes_owned_symlink() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"

    run_installer install
    run_installer uninstall

    assert_path_not_exists "$TMP_HOME/.bashrc" \
        "uninstall: removes owned symlink"
}

test_uninstall_restores_backup() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"
    echo "original" > "$TMP_HOME/.bashrc"

    run_installer install   # backs up .bashrc, creates symlink
    run_installer uninstall # removes symlink, restores backup

    assert_path_not_exists "$TMP_HOME/.bashrc.backup" \
        "uninstall: backup file removed after restore"
    local is_symlink=false
    [[ -L "$TMP_HOME/.bashrc" ]] && is_symlink=true
    assert_equals "false" "$is_symlink" \
        "uninstall: restored path is not a symlink"
    assert_equals "original" "$(cat "$TMP_HOME/.bashrc")" \
        "uninstall: restored file has original content"
}

test_uninstall_skips_non_owned_symlink() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"
    local other_target
    other_target=$(mktemp)
    ln -s "$other_target" "$TMP_HOME/.bashrc"

    run_installer uninstall

    assert_symlink_target "$other_target" "$TMP_HOME/.bashrc" \
        "uninstall: does not remove symlink pointing elsewhere"
    rm -f "$other_target"
}

test_uninstall_skips_plain_file() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"
    echo "not a symlink" > "$TMP_HOME/.bashrc"

    run_installer uninstall

    assert_path_exists "$TMP_HOME/.bashrc" \
        "uninstall: does not remove plain file"
    assert_equals "not a symlink" "$(cat "$TMP_HOME/.bashrc")" \
        "uninstall: plain file content unchanged"
}

test_uninstall_removes_dotfiles_symlink() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"

    run_installer install
    run_installer uninstall

    assert_path_not_exists "$TMP_HOME/.dotfiles" \
        "uninstall: removes ~/.dotfiles symlink"
}

test_uninstall_restores_dotfiles_backup() {
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"
    local prior_dotfiles
    prior_dotfiles=$(mktemp -d)
    ln -s "$prior_dotfiles" "$TMP_HOME/.dotfiles"

    run_installer install   # backs up existing ~/.dotfiles, creates new one
    run_installer uninstall # removes new ~/.dotfiles, restores backup

    assert_symlink_target "$prior_dotfiles" "$TMP_HOME/.dotfiles" \
        "uninstall: restores backed-up ~/.dotfiles symlink"
    rm -rf "$prior_dotfiles"
}

run_test "uninstall - removes owned symlink" test_uninstall_removes_owned_symlink
run_test "uninstall - restores backup" test_uninstall_restores_backup
run_test "uninstall - skips non-owned symlink" test_uninstall_skips_non_owned_symlink
run_test "uninstall - skips plain file" test_uninstall_skips_plain_file
run_test "uninstall - removes ~/.dotfiles symlink" test_uninstall_removes_dotfiles_symlink
run_test "uninstall - restores ~/.dotfiles backup" test_uninstall_restores_dotfiles_backup

# --- Integration: full round-trip ---

test_full_round_trip() {
    # Set up a dotfiles structure with multiple topics
    mkdir -p "$TMP_DOTFILES/bash"
    touch "$TMP_DOTFILES/bash/bashrc.symlink"
    touch "$TMP_DOTFILES/bash/bash_profile.symlink"
    mkdir -p "$TMP_DOTFILES/git"
    touch "$TMP_DOTFILES/git/gitconfig.symlink"
    mkdir -p "$TMP_DOTFILES/vim/vim.symlink"
    touch "$TMP_DOTFILES/vim/vim.symlink/vimrc"
    mkdir -p "$TMP_DOTFILES/aws"  # topic with no .symlink items

    # Pre-existing file that should be backed up
    echo "my gitconfig" > "$TMP_HOME/.gitconfig"

    # Install
    run_installer install

    assert_symlink_target "$TMP_DOTFILES/bash/bashrc.symlink"       "$TMP_HOME/.bashrc"       "round-trip: .bashrc linked"
    assert_symlink_target "$TMP_DOTFILES/bash/bash_profile.symlink" "$TMP_HOME/.bash_profile" "round-trip: .bash_profile linked"
    assert_symlink_target "$TMP_DOTFILES/git/gitconfig.symlink"     "$TMP_HOME/.gitconfig"    "round-trip: .gitconfig linked"
    assert_symlink_target "$TMP_DOTFILES/vim/vim.symlink"           "$TMP_HOME/.vim"          "round-trip: .vim dir linked"
    assert_symlink_target "$TMP_DOTFILES"                           "$TMP_HOME/.dotfiles"     "round-trip: .dotfiles linked"
    assert_path_exists "$TMP_HOME/.gitconfig.backup"                                          "round-trip: pre-existing .gitconfig backed up"
    assert_equals "my gitconfig" "$(cat "$TMP_HOME/.gitconfig.backup")"                      "round-trip: backup has correct content"

    # Uninstall
    run_installer uninstall

    assert_path_not_exists "$TMP_HOME/.bashrc"       "round-trip: .bashrc removed after uninstall"
    assert_path_not_exists "$TMP_HOME/.bash_profile" "round-trip: .bash_profile removed after uninstall"
    assert_path_not_exists "$TMP_HOME/.vim"          "round-trip: .vim removed after uninstall"
    assert_path_not_exists "$TMP_HOME/.dotfiles"     "round-trip: .dotfiles removed after uninstall"
    assert_path_not_exists "$TMP_HOME/.gitconfig.backup" "round-trip: .gitconfig.backup removed after restore"
    assert_equals "my gitconfig" "$(cat "$TMP_HOME/.gitconfig")"  "round-trip: .gitconfig restored with correct content"
}

run_test "full round-trip: install then uninstall" test_full_round_trip

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
