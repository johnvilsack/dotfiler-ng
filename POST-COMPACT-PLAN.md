# Post-Compact Recovery Plan for dotfiler-ng

## Executive Summary
The current dotfiler-ng implementation has become overly complex and bug-prone through feature creep and over-engineering. The original dotfiler was simple, robust, and worked flawlessly. We need to return to that simplicity while switching from symlinks to rsync-based file copying.

## Root Cause Analysis
1. **Over-engineering**: 7-phase sync process vs simple bidirectional sync needed
2. **Path handling complexity**: 3 different path conversion functions with overlapping logic
3. **Feature creep**: Unnecessary functionality like symlink migration, complex tombstone lifecycle
4. **Code duplication**: Both sync.sh and build.sh with overlapping functionality
5. **Inadequate testing**: Complex interdependencies make testing and debugging difficult

## Simplified Architecture (Based on CLAUDE.md)

### Commands (5 total)
```
dotfiler track <path>     # Add to tracked.conf
dotfiler ignore <pattern> # Add to ignored.conf  
dotfiler delete <path>    # Add to deleted.conf, remove files
dotfiler sync [--repo-first] # Core bidirectional sync
dotfiler list            # Show tracked paths
dotfiler status          # Show config health
```

### Files Structure
```
~/.config/dotfiler/
├── config              # Basic settings only
├── tracked.conf        # Files/folders to sync
├── ignored.conf        # Patterns to ignore
└── deleted.conf        # Tombstones with timestamps
```

### Core Logic Flow

#### Normal Sync (`dotfiler sync`)
1. Detect filesystem deletions → update deleted.conf
2. FS → Repo sync (tracked items only, respect ignores)
3. Repo → FS sync (tracked items only)
4. Enforce deletions from deleted.conf
5. Cleanup expired tombstones

#### First-time Install (`dotfiler sync --repo-first`)
1. Replace any symlinks with files
2. Repo → FS sync (overwrite mode)
3. Skip FS → Repo sync

## Implementation Plan

### Phase 1: Core Infrastructure (Day 1)
**Goal**: Get basic functionality working bug-free

1. **Simplify common.sh**
   - Single `normalize_path()` function
   - Single `convert_to_repo_path()` function  
   - Single `convert_to_fs_path()` function
   - Robust environment variable handling

2. **Create simple config.sh**
   - Basic config loading only
   - Environment variable defaults
   - No complex initialization logic

3. **Create minimal track.sh**
   - Add paths to tracked.conf
   - Basic validation only
   - No complex parent directory logic

### Phase 2: Core Sync Engine (Day 2)
**Goal**: Replace complex sync with simple bidirectional rsync

1. **Create new simple sync.sh**
   - Single sync function with clear phases
   - Use rsync directly, not custom wrappers
   - Simple deletion detection using rsync --dry-run
   - Clear error handling

2. **Remove bloated files**
   - Delete current sync.sh entirely
   - Delete init.sh entirely  
   - Delete build.sh entirely
   - Keep only add.sh, ignore.sh, delete.sh with simplifications

### Phase 3: Deletion Management (Day 3)
**Goal**: Simple but effective deletion tracking

1. **Simplify delete.sh**
   - Single deletion function
   - Simple tombstone format: `path|timestamp`
   - 90-day enforcement, 120-day cleanup
   - No complex lifecycle management

2. **Integration with sync**
   - Deletion detection in sync process
   - Cross-machine deletion enforcement
   - Automatic tombstone cleanup

### Phase 4: Testing and Validation (Day 4)
**Goal**: Ensure reliability through comprehensive testing

## Critical Tests Required

### Path Handling Tests
```bash
# Test environment variable support
test_path_expansion() {
    local test_path="$HOME/.testfile"
    local repo_path=$(convert_to_repo_path "$test_path")
    [[ "$repo_path" == "\$HOME/.testfile" ]] || fail
}

# Test absolute path handling
test_absolute_paths() {
    local test_path="/etc/test"
    local repo_path=$(convert_to_repo_path "$test_path")
    [[ "$repo_path" == "/etc/test" ]] || fail
}

# Test bidirectional conversion
test_path_roundtrip() {
    local original="$HOME/.config/test"
    local repo_format=$(convert_to_repo_path "$original")
    local back_to_fs=$(convert_to_fs_path "$repo_format")
    [[ "$original" == "$back_to_fs" ]] || fail
}
```

### Sync Operation Tests
```bash
# Test basic file sync
test_file_sync() {
    echo "test" > "$HOME/testfile"
    dotfiler track "$HOME/testfile"
    dotfiler sync
    [[ -f "$REPO/HOME/testfile" ]] || fail
    [[ "$(cat "$REPO/HOME/testfile")" == "test" ]] || fail
}

# Test directory sync
test_directory_sync() {
    mkdir -p "$HOME/.testdir"
    echo "content" > "$HOME/.testdir/file"
    dotfiler track "$HOME/.testdir"
    dotfiler sync
    [[ -f "$REPO/HOME/.testdir/file" ]] || fail
}

# Test deletion detection
test_deletion_detection() {
    echo "test" > "$HOME/deltest"
    dotfiler track "$HOME/deltest"
    dotfiler sync
    rm "$HOME/deltest"
    dotfiler sync
    grep -q "\$HOME/deltest" ~/.config/dotfiler/deleted.conf || fail
    [[ ! -f "$REPO/HOME/deltest" ]] || fail
}

# Test repo-first mode
test_repo_first() {
    echo "repo version" > "$REPO/HOME/repotest"
    echo "fs version" > "$HOME/repotest"
    dotfiler sync --repo-first
    [[ "$(cat "$HOME/repotest")" == "repo version" ]] || fail
}
```

### Configuration Tests
```bash
# Test config file loading
test_config_loading() {
    local test_repo="/tmp/test-dotfiles"
    echo "REPO_PATH=$test_repo" > ~/.config/dotfiler/config
    load_config
    [[ "$REPO_PATH" == "$test_repo" ]] || fail
}

# Test environment variable defaults
test_env_defaults() {
    DOTFILESPATH="/custom/path" load_config
    [[ "$REPO_PATH" == "/custom/path" ]] || fail
}
```

## Quality Gates

### Before Each Commit
1. All existing tests must pass
2. New functionality must have corresponding tests
3. No functions over 50 lines
4. No files over 200 lines
5. All paths must use environment variables for $HOME

### Integration Testing
1. Complete sync cycle: track → sync → delete → sync
2. Cross-machine simulation using different $HOME values
3. Large directory handling (100+ files)
4. Special character handling in filenames
5. Concurrent sync prevention

## Success Metrics

### Functionality 
- [ ] All 5 commands work correctly
- [ ] Bidirectional sync maintains consistency
- [ ] Deletion tracking works across "machines"
- [ ] Environment variables work correctly
- [ ] Repo-first mode overwrites properly

### Code Quality
- [ ] Total codebase under 1000 lines
- [ ] No function over 50 lines
- [ ] No code duplication
- [ ] Clear, single-responsibility functions
- [ ] Comprehensive error handling

### User Experience
- [ ] Clear error messages
- [ ] Fast sync operations
- [ ] No unexpected behavior
- [ ] Intuitive command interface
- [ ] Reliable cross-machine operation

## Risk Mitigation

### If We Fall Into Old Patterns
**STOP immediately if:**
- Any function exceeds 50 lines
- Path handling gets split across multiple functions
- Sync process becomes multi-phase
- Duplicate functionality appears
- Testing becomes difficult

### Rollback Strategy
- Keep current working version in `dotfiler-ng-backup` branch
- Each phase should be independently functional
- Maintain ability to revert to previous phase
- User data (config files) should never be lost

## Post-Implementation

### Documentation Requirements
1. Simple README with 5 commands
2. Configuration file format specification
3. Troubleshooting guide for common issues
4. Migration guide from original dotfiler

### Maintenance Plan
1. Monthly test run to verify core functionality
2. Quarterly review for potential simplifications
3. Resist all feature requests that add complexity
4. Maintain test coverage above 90%

## Key Principles Going Forward

1. **KISS**: Keep It Simple, Stupid - every line of code must justify its existence
2. **Single Responsibility**: Each function does one thing well
3. **Fail Fast**: Clear error messages, no silent failures
4. **Test Everything**: No untested code in the main branch
5. **Environment First**: All paths must support environment variables
6. **User Safety**: Confirmation prompts for destructive operations

This plan prioritizes getting back to working, maintainable code over preserving the current complex implementation. The goal is a robust, simple tool that works reliably rather than a feature-rich tool that breaks frequently.