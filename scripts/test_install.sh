#!/usr/bin/env bash
# Test harness for scripts/install.sh
# Uses temp directories to isolate tests from the real home directory.

PASS=0
FAIL=0
ERRORS=()

# --- Harness helpers ---

assert_equals() {
    local expected="$1" actual="$2" msg="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: $msg"
        ((PASS++))
    else
        echo "  FAIL: $msg"
        echo "    expected: $(printf '%q' "$expected")"
        echo "    actual:   $(printf '%q' "$actual")"
        ((FAIL++))
        ERRORS+=("$msg")
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
        ((PASS++))
    else
        echo "  FAIL: $msg (path does not exist: $path)"
        ((FAIL++))
        ERRORS+=("$msg")
    fi
}

assert_path_not_exists() {
    local path="$1" msg="$2"
    if [[ ! -e "$path" && ! -L "$path" ]]; then
        echo "  PASS: $msg"
        ((PASS++))
    else
        echo "  FAIL: $msg (path unexpectedly exists: $path)"
        ((FAIL++))
        ERRORS+=("$msg")
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

# (tests will be added in subsequent tasks)

# --- Name derivation tests ---

test_derive_target_from_file() {
    # Create a minimal topic/file.symlink structure
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

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    echo "Failed tests:"
    for err in "${ERRORS[@]}"; do
        echo "  - $err"
    done
    exit 1
fi
exit 0
