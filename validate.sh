#!/usr/bin/env bash
# validate.sh - Comprehensive validation of dotfiler-ng functionality
# Tests all requirements from checklist.md

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directories
TEST_HOME="$HOME/validate-dotfiler"
TEST_SYSTEM="/tmp/validate-dotfiler"
REPO_HOME="$HOME/github/dotfiles/mac/files/HOME"
REPO_ROOT="$HOME/github/dotfiles/mac/files"

# Counters
PASSED=0
FAILED=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

info() {
    echo -e "${YELLOW}→${NC} $1"
}

cleanup() {
    info "Cleaning up test environment..."
    rm -rf "$TEST_HOME" "$TEST_SYSTEM" 2>/dev/null
    rm -rf "$REPO_HOME/validate-dotfiler" "$REPO_ROOT/tmp/validate-dotfiler" 2>/dev/null
    > ~/.config/dotfiler/tracked.conf
    > ~/.config/dotfiler/ignored.conf  
    > ~/.config/dotfiler/deleted.conf
}

# Backup existing config
backup_config() {
    mkdir -p ~/.config/dotfiler-backup
    cp ~/.config/dotfiler/*.conf ~/.config/dotfiler-backup/ 2>/dev/null || true
}

# Restore config
restore_config() {
    cp ~/.config/dotfiler-backup/*.conf ~/.config/dotfiler/ 2>/dev/null || true
    rm -rf ~/.config/dotfiler-backup
}

# Test 1: Tracking functionality
test_tracking() {
    info "Testing tracking functionality..."
    
    # Test HOME path with $HOME
    mkdir -p "$TEST_HOME"
    echo "test1" > "$TEST_HOME/file1.txt"
    dotfiler track "$TEST_HOME/file1.txt" > /dev/null 2>&1
    
    if grep -q "\$HOME/validate-dotfiler/file1.txt" ~/.config/dotfiler/tracked.conf; then
        pass "HOME paths stored with \$HOME variable"
    else
        fail "HOME paths not stored correctly"
    fi
    
    # Test ~ path conversion
    echo "test2" > "$TEST_HOME/file2.txt"
    dotfiler track "~/validate-dotfiler/file2.txt" > /dev/null 2>&1
    
    if grep -q "\$HOME/validate-dotfiler/file2.txt" ~/.config/dotfiler/tracked.conf; then
        pass "~ paths converted to \$HOME"
    else
        fail "~ paths not converted correctly"
    fi
    
    # Test system path
    mkdir -p "$TEST_SYSTEM"
    echo "system" > "$TEST_SYSTEM/system.txt"
    dotfiler track "$TEST_SYSTEM/system.txt" > /dev/null 2>&1
    
    if grep -q "/tmp/validate-dotfiler/system.txt" ~/.config/dotfiler/tracked.conf; then
        pass "System paths stored as absolute paths"
    else
        fail "System paths not stored correctly"
    fi
}

# Test 2: Repository structure
test_repo_structure() {
    info "Testing repository structure..."
    
    # Check HOME files go to HOME directory
    if [[ -f "$REPO_HOME/validate-dotfiler/file1.txt" ]]; then
        pass "HOME files sync to repo HOME directory"
    else
        fail "HOME files not in correct repo location"
    fi
    
    # Check system files go to full path
    if [[ -f "$REPO_ROOT/tmp/validate-dotfiler/system.txt" ]] || [[ -f "$REPO_ROOT/private/tmp/validate-dotfiler/system.txt" ]]; then
        pass "System files sync to full path in repo"
    else
        fail "System files not in correct repo location"
    fi
}

# Test 3: Variable expansion for rsync
test_variable_expansion() {
    info "Testing variable expansion..."
    
    # Create a file and sync it
    echo "expansion test" > "$TEST_HOME/expand.txt"
    dotfiler track "$TEST_HOME/expand.txt" > /dev/null 2>&1
    
    # If the file exists in the repo, rsync must have expanded the paths correctly
    if [[ -f "$REPO_HOME/validate-dotfiler/expand.txt" ]]; then
        pass "Paths expanded to real paths for rsync"
    else
        fail "Paths not properly expanded for rsync"
    fi
}

# Test 4: Bidirectional sync
test_bidirectional_sync() {
    info "Testing bidirectional sync..."
    
    # Test FS newer than repo
    echo "fs newer" > "$TEST_HOME/bidirect.txt"
    dotfiler track "$TEST_HOME/bidirect.txt" > /dev/null 2>&1
    sleep 1
    echo "fs newest" > "$TEST_HOME/bidirect.txt"
    dotfiler sync > /dev/null 2>&1
    
    if grep -q "fs newest" "$REPO_HOME/validate-dotfiler/bidirect.txt"; then
        pass "Newer filesystem files sync to repo"
    else
        fail "Filesystem changes not syncing to repo"
    fi
    
    # Test repo newer than FS
    sleep 1
    echo "repo newest" > "$REPO_HOME/validate-dotfiler/bidirect.txt"
    dotfiler sync > /dev/null 2>&1
    
    if grep -q "repo newest" "$TEST_HOME/bidirect.txt"; then
        pass "Newer repo files sync to filesystem"
    else
        fail "Repository changes not syncing to filesystem"
    fi
}

# Test 5: Deletion detection
test_deletion_detection() {
    info "Testing deletion detection..."
    
    # Test filesystem deletion
    echo "delete me" > "$TEST_HOME/delete1.txt"
    dotfiler track "$TEST_HOME/delete1.txt" > /dev/null 2>&1
    rm "$TEST_HOME/delete1.txt"
    dotfiler sync > /dev/null 2>&1
    
    if grep -q "\$HOME/validate-dotfiler/delete1.txt" ~/.config/dotfiler/deleted.conf; then
        pass "Filesystem deletions detected and tombstoned"
    else
        fail "Filesystem deletions not detected"
    fi
    
    if grep -q "\$HOME/validate-dotfiler/delete1.txt" ~/.config/dotfiler/ignored.conf; then
        pass "Deletions added to ignore list"
    else
        fail "Deletions not added to ignore list"
    fi
    
    if [[ ! -f "$REPO_HOME/validate-dotfiler/delete1.txt" ]]; then
        pass "Deleted files removed from repository"
    else
        fail "Deleted files not removed from repository"
    fi
    
    # Test repository deletion
    echo "repo delete" > "$TEST_HOME/delete2.txt"
    dotfiler track "$TEST_HOME/delete2.txt" > /dev/null 2>&1
    rm "$REPO_HOME/validate-dotfiler/delete2.txt"
    dotfiler sync > /dev/null 2>&1
    
    if [[ ! -f "$TEST_HOME/delete2.txt" ]]; then
        pass "Repository deletions sync to filesystem"
    else
        fail "Repository deletions not syncing"
    fi
    
    if grep -q "\$HOME/validate-dotfiler/delete2.txt" ~/.config/dotfiler/deleted.conf; then
        pass "Repository deletions tombstoned"
    else
        fail "Repository deletions not tombstoned"
    fi
}

# Test 6: Ignore patterns
test_ignore_patterns() {
    info "Testing ignore patterns..."
    
    # Add ignore pattern
    dotfiler ignore "*.log" > /dev/null 2>&1
    
    # Create ignored and non-ignored files
    echo "log" > "$TEST_HOME/test.log"
    echo "txt" > "$TEST_HOME/test.txt"
    dotfiler track "$TEST_HOME" > /dev/null 2>&1
    dotfiler sync > /dev/null 2>&1
    
    if [[ ! -f "$REPO_HOME/validate-dotfiler/test.log" ]]; then
        pass "Ignored patterns excluded from sync"
    else
        fail "Ignored patterns not working"
    fi
    
    if [[ -f "$REPO_HOME/validate-dotfiler/test.txt" ]]; then
        pass "Non-ignored files sync normally"
    else
        fail "Non-ignored files not syncing"
    fi
}

# Test 7: Repo-first mode
test_repo_first() {
    info "Testing --repo-first mode..."
    
    # Create repo-only file
    mkdir -p "$REPO_HOME/validate-dotfiler"
    echo "repo only" > "$REPO_HOME/validate-dotfiler/repo-only.txt"
    echo "\$HOME/validate-dotfiler/repo-only.txt" >> ~/.config/dotfiler/tracked.conf
    
    # Create conflicting filesystem file
    echo "filesystem version" > "$TEST_HOME/repo-only.txt"
    
    # Run repo-first sync
    dotfiler sync --repo-first > /dev/null 2>&1
    
    if grep -q "repo only" "$TEST_HOME/repo-only.txt"; then
        pass "--repo-first overwrites filesystem"
    else
        fail "--repo-first not overwriting filesystem"
    fi
}

# Test 8: Deletion enforcement order
test_deletion_order() {
    info "Testing deletion enforcement order..."
    
    # Create a file that should be deleted
    echo "to delete" > "$TEST_HOME/enforce.txt"
    dotfiler track "$TEST_HOME/enforce.txt" > /dev/null 2>&1
    
    # Add to deletion list manually
    echo "\$HOME/validate-dotfiler/enforce.txt|$(date +%s)" >> ~/.config/dotfiler/deleted.conf
    
    # Create the file again (simulating it being recreated)
    echo "recreated" > "$TEST_HOME/enforce.txt"
    
    # Run sync - deletion should be enforced FIRST
    dotfiler sync > /dev/null 2>&1
    
    if [[ ! -f "$TEST_HOME/enforce.txt" ]]; then
        pass "Deletions enforced before syncing"
    else
        fail "Deletions not enforced early enough"
    fi
}

# Test 9: Commands work
test_commands() {
    info "Testing commands..."
    
    # Test add (alias for track)
    echo "add test" > "$TEST_HOME/add.txt"
    if dotfiler add "$TEST_HOME/add.txt" > /dev/null 2>&1; then
        pass "dotfiler add works"
    else
        fail "dotfiler add failed"
    fi
    
    # Test ignore
    if dotfiler ignore "*.tmp" > /dev/null 2>&1; then
        pass "dotfiler ignore works"
    else
        fail "dotfiler ignore failed"
    fi
    
    # Test sync
    if dotfiler sync > /dev/null 2>&1; then
        pass "dotfiler sync works"
    else
        fail "dotfiler sync failed"
    fi
    
    # Test sync --repo-first
    if dotfiler sync --repo-first > /dev/null 2>&1; then
        pass "dotfiler sync --repo-first works"
    else
        fail "dotfiler sync --repo-first failed"
    fi
}

# Main test execution
main() {
    echo "================================================"
    echo "     Dotfiler-NG Comprehensive Validation"
    echo "================================================"
    echo
    
    # Backup existing config
    backup_config
    
    # Clean environment
    cleanup
    
    # Run tests
    test_tracking
    test_repo_structure
    test_variable_expansion
    test_bidirectional_sync
    test_deletion_detection
    test_ignore_patterns
    test_repo_first
    test_deletion_order
    test_commands
    
    # Summary
    echo
    echo "================================================"
    echo "                Test Results"
    echo "================================================"
    echo -e "Passed: ${GREEN}$PASSED${NC}"
    echo -e "Failed: ${RED}$FAILED${NC}"
    
    if [[ $FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All validation tests passed!${NC}"
        cleanup
        restore_config
        exit 0
    else
        echo -e "\n${RED}Some tests failed. Please review the output.${NC}"
        echo -e "${YELLOW}Test files preserved for debugging.${NC}"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi