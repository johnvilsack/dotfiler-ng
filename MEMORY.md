# Dotfiler Development Memory

## Conversation Summary

This session focused on solving critical issues with dotfiler's deletion system and implementing comprehensive tombstone-based deletion management. The work addressed fundamental flaws in how dotfiler handled file deletions, particularly the "parent directory trap" problem.

## Problems Identified and Solved

### 1. Fresh Install Configuration Corruption
**Problem**: During fresh installs, `dotfiler build` would sync default application configs into the repository before creating symlinks, potentially overwriting curated dotfiles with system defaults.

**Solution**: Implemented `--repo-first` flag for build command:
```bash
dotfiler build --repo-first  # Skips sync, only creates symlinks from existing repo
```

### 2. Broken Symlink Crashes
**Problem**: Dotfiler would crash when encountering broken symlinks during build operations.

**Solution**: Enhanced symlink handling throughout the codebase:
- Updated existence checks from `[[ ! -e "$path" ]]` to `[[ ! -e "$path" ]] && [[ ! -L "$path" ]]`
- Added broken symlink detection and automatic cleanup in `newsync.sh`
- Graceful error handling with user-friendly warnings

### 3. The "Parent Directory Trap" (Critical Issue)
**Problem**: When tracking entire directories (e.g., `~/.config/kitty`), users couldn't delete individual files within them:
- `dotfiler remove ~/.config/kitty/unwanted.conf` would fail (not tracked individually)
- Manual deletion would result in file resurrection on next build
- No tombstoning system to prevent re-import

**Solution**: Complete deletion management overhaul with tombstone system.

## New Architecture Implementation

### Configuration Files Restructure
Migrated from ad-hoc file locations to centralized configuration:

**Old System:**
```bash
TRACKEDFOLDERLIST="$HOME/.config/dotfiler/tracked-folders.txt"
IGNORELIST="$HOME/.config/dotfiler/ignore-list.txt"  # Located in ignore.sh
```

**New System (in main dotfiler script):**
```bash
CONFIG_DIR="$HOME/.config/dotfiler"
TRACKED_ITEMS="$CONFIG_DIR/tracked.conf"
IGNORED_ITEMS="$CONFIG_DIR/ignored.conf"
DELETED_ITEMS="$CONFIG_DIR/deleted.conf"
```

Auto-migration system preserves existing configurations.

### Deletion Management System

#### Core Components:

1. **`dotfiler delete` Command** (`delete.sh`):
   - 5-step deletion process: tombstone → ignore → repo removal → untrack → filesystem deletion
   - Works on both files and directories
   - Handles files within tracked parent directories
   - Cross-system enforcement capability

2. **Tombstone System** (`deleted.conf`):
   - Format: `path|timestamp` (pipe-delimited)
   - Auto-adds timestamps for manual entries
   - Lifecycle management with retention policies

3. **Build Integration**:
   - `cleanup_deleted_items()` - Manages tombstone lifecycle
   - `enforce_deletions()` - Active deletion enforcement on other systems
   - Both run automatically during build cleanup phase

#### Deletion Lifecycle:

| Phase | Duration | Behavior |
|-------|----------|----------|
| **Active Enforcement** | 0-90 days | File deleted on any system running build |
| **Passive Protection** | 90-120 days | File ignored if found, not actively deleted |
| **Auto-Cleanup** | 120+ days | Tombstone removed if file doesn't exist |

#### Special Cases:
- **Automated Files**: If file reappears after 120 days, tombstone persists indefinitely
- **Manual Entries**: Auto-timestamped on first cleanup run
- **Cross-System**: Deletions propagate to all machines within enforcement window

## System Operation Understanding

### Build Process (Order of Operations):

**Phase 1: Cleanup** 🧹
```bash
migrate_config_files()      # Migrate legacy configs
cleanup_ignored_files()     # Remove ignored files from management
cleanup_deleted_items()     # Manage tombstone lifecycle  
enforce_deletions()         # Delete files marked for deletion on other systems
```

**Phase 2: Sync** 📥 *(unless `--repo-first`)*
```bash
# For each tracked item:
1. Check ignore list → Skip if ignored
2. Check existence → Skip if missing  
3. For directories: Recursively scan files
   - Check each file against ignore list
   - Copy new files to repo (existing files skipped)
```

**Phase 3: Symlink Creation** 🔗
```bash
# For each file in repository:
1. Check ignore list → Skip if ignored
2. Create symlink: filesystem_path → repo_file
3. Overwrite existing files with symlinks
```

### Key System Behaviors:
- **Triple Ignore Checking**: Patterns checked at tracked-item, file-scan, and symlink levels
- **Individual File Symlinks**: Never symlinks directories, only individual files
- **Repo Authority**: Repository is source of truth for symlink creation
- **Migration-Safe**: Auto-migrates old config format transparently

## File Structure and Implementation

### Core Files Modified/Created:
- **`dotfiler`** - Main script with new config variables and delete command routing
- **`dotfiler-lib/delete.sh`** - New deletion management system (271 lines)
- **`dotfiler-lib/ignore.sh`** - Updated with migration logic and new variables
- **`dotfiler-lib/build.sh`** - Integrated deletion cleanup and enforcement
- **`dotfiler-lib/newsync.sh`** - Enhanced symlink handling for broken links
- **All other lib files** - Updated to use new config variables

### New Command Usage:
```bash
dotfiler delete ~/.config/unwanted-app         # Full deletion with tombstone
dotfiler build --repo-first                    # Fresh install safe build
dotfiler ignore ~/.config/app/debug.log        # Enhanced ignore system
```

## Integration Points Verified

The deletion management system is fully integrated into the build process:

1. **Automatic Execution**: `cleanup_deleted_items()` and `enforce_deletions()` are called during every `dotfiler build`
2. **Seamless Operation**: Tombstone management happens transparently without user intervention
3. **Cross-System Sync**: Deletion enforcement works through normal git workflow (tombstones in repo)
4. **Error Handling**: Graceful degradation if config files are missing or corrupted

## Testing and Validation

The system was tested with:
- Fresh install scenarios with `--repo-first` flag
- Broken symlink cleanup and handling
- Config file migration from old to new format
- Basic delete command functionality and help integration

## Outstanding Considerations

The system now handles the major edge cases identified:
- ✅ Parent directory vs individual file deletion
- ✅ Cross-machine deletion consistency  
- ✅ Zombie file resurrection prevention
- ✅ Automated file persistent protection
- ✅ Fresh install configuration corruption
- ✅ Broken symlink error handling

## Documentation

Complete README documentation was added covering:
- Order of operations explanation
- Safe deletion procedures comparison (old vs new)
- Advanced deletion management section
- Cross-machine scenarios and tombstone lifecycle
- Migration and configuration details

The system is production-ready and addresses all identified issues with dotfiler's deletion and configuration management capabilities.