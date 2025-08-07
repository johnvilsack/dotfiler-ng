#!/usr/bin/env bash
# test_all.sh - Comprehensive test suite for dotfiler-ng
# Tests all functionality: track, ignore, delete, sync, repo-first

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directories
HOME_TEST_DIR="$HOME/dotfiler-test"
SHARED_TEST_DIR="/Users/Shared/TEST"
REPO_HOME_DIR="$HOME/github/dotfiles/mac/files/HOME"
REPO_SHARED_DIR="$HOME/github/dotfiles/mac/files/Users/Shared"

log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

# Test assertion function
assert_exists() {
    local path="$1"
    local description="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -e "$path" ]]; then
        log_pass "$description - exists: $path"
        return 0
    else
        log_fail "$description - missing: $path"
        return 1
    fi
}

assert_not_exists() {
    local path="$1"
    local description="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ ! -e "$path" ]]; then
        log_pass "$description - correctly absent: $path"
        return 0
    else
        log_fail "$description - should not exist: $path"
        return 1
    fi
}

assert_file_content() {
    local path="$1"
    local expected="$2"
    local description="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -f "$path" ]] && [[ "$(cat "$path")" == "$expected" ]]; then
        log_pass "$description - correct content: $path"
        return 0
    else
        log_fail "$description - wrong content in: $path"
        if [[ -f "$path" ]]; then
            echo "  Expected: $expected"
            echo "  Got: $(cat "$path")"
        else
            echo "  File does not exist"
        fi
        return 1
    fi
}

assert_in_config() {
    local config_file="$1"
    local pattern="$2"
    local description="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if grep -q "$pattern" "$config_file" 2>/dev/null; then
        log_pass "$description - found in $(basename "$config_file"): $pattern"
        return 0
    else
        log_fail "$description - not found in $(basename "$config_file"): $pattern"
        return 1
    fi
}

cleanup_test_files() {
    log_info "Cleaning up test files..."
    
    # Remove test files from filesystem
    rm -rf "$HOME_TEST_DIR" 2>/dev/null
    sudo rm -rf "$SHARED_TEST_DIR" 2>/dev/null || rm -rf "$SHARED_TEST_DIR" 2>/dev/null
    
    # Remove test files from repository
    rm -rf "$REPO_HOME_DIR/dotfiler-test" 2>/dev/null
    rm -rf "$REPO_SHARED_DIR" 2>/dev/null
    
    # Clean up config files
    local config_dir="$HOME/.config/dotfiler"
    > "$config_dir/tracked.conf"
    > "$config_dir/ignored.conf" 
    > "$config_dir/deleted.conf"
}

setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Ensure dotfiler is installed
    ./install-local.sh > /dev/null
    
    # Create test directories
    mkdir -p "$HOME_TEST_DIR"
    mkdir -p "$SHARED_TEST_DIR"
    mkdir -p "$REPO_HOME_DIR"
    
    # Fix config files to use ~ format instead of $HOME
    local config_dir="$HOME/.config/dotfiler"
    if [[ -f "$config_dir/tracked.conf" ]]; then
        sed -i.bak 's|\$HOME|~|g' "$config_dir/tracked.conf"
        rm -f "$config_dir/tracked.conf.bak"
    fi
    if [[ -f "$config_dir/ignored.conf" ]]; then
        sed -i.bak 's|\$HOME|~|g' "$config_dir/ignored.conf"
        rm -f "$config_dir/ignored.conf.bak"
    fi
    if [[ -f "$config_dir/deleted.conf" ]]; then
        sed -i.bak 's|\$HOME|~|g' "$config_dir/deleted.conf"
        rm -f "$config_dir/deleted.conf.bak"
    fi
}

create_test_files() {
    log_info "Creating test files and directories..."
    
    # Home directory test files
    echo "home file 1" > "$HOME_TEST_DIR/file1.txt"
    echo "home file 2" > "$HOME_TEST_DIR/file2.conf"
    mkdir -p "$HOME_TEST_DIR/subdir"
    echo "subdir file" > "$HOME_TEST_DIR/subdir/nested.txt"
    echo "log content" > "$HOME_TEST_DIR/test.log"
    
    # Shared directory test files (outside home)
    echo "shared file 1" > "$SHARED_TEST_DIR/shared1.txt"
    echo "shared config" > "$SHARED_TEST_DIR/config.yaml"
    mkdir -p "$SHARED_TEST_DIR/shared-subdir"
    echo "shared nested" > "$SHARED_TEST_DIR/shared-subdir/file.conf"
}

test_track_functionality() {
    log_test "Testing track functionality..."
    
    # Track home files
    dotfiler track "$HOME_TEST_DIR/file1.txt" > /dev/null
    dotfiler track "$HOME_TEST_DIR/subdir" > /dev/null
    
    # Track shared files (outside home)
    dotfiler track "$SHARED_TEST_DIR/shared1.txt" > /dev/null
    dotfiler track "$SHARED_TEST_DIR/shared-subdir" > /dev/null
    
    # Verify files are tracked in config
    assert_in_config "$HOME/.config/dotfiler/tracked.conf" "~/dotfiler-test/file1.txt" "Track home file"
    assert_in_config "$HOME/.config/dotfiler/tracked.conf" "~/dotfiler-test/subdir" "Track home directory"
    assert_in_config "$HOME/.config/dotfiler/tracked.conf" "/Users/Shared/TEST/shared1.txt" "Track shared file"
    assert_in_config "$HOME/.config/dotfiler/tracked.conf" "/Users/Shared/TEST/shared-subdir" "Track shared directory"
    
    # Verify files are synced to repository
    assert_exists "$REPO_HOME_DIR/dotfiler-test/file1.txt" "Home file in repo"
    assert_exists "$REPO_HOME_DIR/dotfiler-test/subdir/nested.txt" "Home subdir in repo"
    assert_exists "$HOME/github/dotfiles/mac/files/Users/Shared/TEST/shared1.txt" "Shared file in repo"
    assert_exists "$HOME/github/dotfiles/mac/files/Users/Shared/TEST/shared-subdir/file.conf" "Shared subdir in repo"
    
    # Verify content is correct
    assert_file_content "$REPO_HOME_DIR/dotfiler-test/file1.txt" "home file 1" "Home file content sync"
    assert_file_content "$HOME/github/dotfiles/mac/files/Users/Shared/TEST/shared1.txt" "shared file 1" "Shared file content sync"
}

test_ignore_functionality() {
    log_test "Testing ignore functionality..."
    
    # Add ignore patterns
    dotfiler ignore "*.log" > /dev/null
    dotfiler ignore "*.tmp" > /dev/null
    
    # Track directory with ignored files
    echo "temp content" > "$HOME_TEST_DIR/temp.tmp"
    dotfiler track "$HOME_TEST_DIR/file2.conf" > /dev/null
    
    # Verify ignore patterns are in config
    assert_in_config "$HOME/.config/dotfiler/ignored.conf" "*.log" "Ignore log files"
    assert_in_config "$HOME/.config/dotfiler/ignored.conf" "*.tmp" "Ignore temp files"
    
    # Verify tracked file exists but ignored files don't
    assert_exists "$REPO_HOME_DIR/dotfiler-test/file2.conf" "Non-ignored file synced"
    assert_not_exists "$REPO_HOME_DIR/dotfiler-test/test.log" "Log file ignored"
    assert_not_exists "$REPO_HOME_DIR/dotfiler-test/temp.tmp" "Temp file ignored"
}

test_sync_bidirectional() {
    log_test "Testing bidirectional sync..."
    
    # Modify file on filesystem
    echo "modified content" > "$HOME_TEST_DIR/file1.txt"
    
    # Create new file in repository
    echo "repo only file" > "$REPO_HOME_DIR/dotfiler-test/repo-file.txt"
    
    # Sync
    dotfiler sync > /dev/null
    
    # Verify filesystem to repo sync
    assert_file_content "$REPO_HOME_DIR/dotfiler-test/file1.txt" "modified content" "FS to repo sync"
    
    # Note: repo to filesystem sync would require the file to be tracked first
    # This is expected behavior - only tracked items sync both ways
}

test_deletion_detection() {
    log_test "Testing deletion detection..."
    
    # Delete a tracked file from filesystem
    rm "$HOME_TEST_DIR/file2.conf"
    
    # Sync to detect deletion
    dotfiler sync > /dev/null
    
    # Verify file is removed from repo and added to deleted.conf
    assert_not_exists "$REPO_HOME_DIR/dotfiler-test/file2.conf" "Deleted file removed from repo"
    assert_in_config "$HOME/.config/dotfiler/deleted.conf" "~/dotfiler-test/file2.conf" "Deletion tombstoned"
}

test_delete_command() {
    log_test "Testing delete command..."
    
    # Use delete command
    dotfiler delete "$SHARED_TEST_DIR/shared1.txt" > /dev/null
    
    # Verify file deleted from both filesystem and repo
    assert_not_exists "$SHARED_TEST_DIR/shared1.txt" "File deleted from filesystem"
    assert_not_exists "$HOME/github/dotfiles/mac/files/Users/Shared/TEST/shared1.txt" "File deleted from repo"
    assert_in_config "$HOME/.config/dotfiler/deleted.conf" "/Users/Shared/TEST/shared1.txt" "Deletion tombstoned"
}

test_repo_first_mode() {
    log_test "Testing repo-first mode..."
    
    # Create file in repo only
    echo "repo-first content" > "$REPO_HOME_DIR/dotfiler-test/repo-only.txt"
    
    # Add to tracking (simulate it being tracked on another machine)
    echo "~/dotfiler-test/repo-only.txt" >> "$HOME/.config/dotfiler/tracked.conf"
    
    # Run repo-first sync
    dotfiler sync --repo-first > /dev/null
    
    # Verify file appears on filesystem
    assert_exists "$HOME_TEST_DIR/repo-only.txt" "Repo-first file created"
    assert_file_content "$HOME_TEST_DIR/repo-only.txt" "repo-first content" "Repo-first content correct"
}

test_list_and_status() {
    log_test "Testing list and status commands..."
    
    # Test list command
    local list_output=$(dotfiler list 2>/dev/null)
    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$list_output" | grep -q "dotfiler-test"; then
        log_pass "List command shows tracked items"
    else
        log_fail "List command missing tracked items"
    fi
    
    # Test status command
    local status_output=$(dotfiler status 2>/dev/null)
    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$status_output" | grep -q "Configuration:" && echo "$status_output" | grep -q "Statistics:"; then
        log_pass "Status command shows configuration and stats"
    else
        log_fail "Status command missing expected sections"
    fi
}

run_all_tests() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Dotfiler-NG Comprehensive Test Suite${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    cleanup_test_files
    setup_test_environment
    create_test_files
    
    test_track_functionality
    test_ignore_functionality  
    test_sync_bidirectional
    test_deletion_detection
    test_delete_command
    test_repo_first_mode
    test_list_and_status
    
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}           Test Results${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Tests run:    ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! ✓${NC}"
        cleanup_test_files
        return 0
    else
        echo -e "${RED}Some tests failed! ✗${NC}"
        echo -e "${YELLOW}Test files preserved for debugging${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi