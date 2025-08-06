# Dotfiler-NG Development Memory

## Architecture Decisions

### Core Technology: Rsync
Selected rsync over rclone for these reasons:
- Native deletion detection with `--delete --dry-run`
- Direct support for simple path lists (tracked.conf)
- Direct .gitignore support via `--exclude-from`
- Environment variable expansion through shell
- Simpler implementation without format conversion

### Key Design Principles
1. **No Symlinks**: Copy actual files to avoid edge cases
2. **Bidirectional Sync**: Filesystem→Repo (new only), Repo→Filesystem (all tracked)
3. **Simple Config Format**: Plain path lists, no complex syntax
4. **Git Integration**: Leverage git for cross-machine state
5. **Backwards Compatible**: Support migration from original dotfiler

### Configuration Structure
```
$HOME/.config/dotfiler/
├── config           # Main config (repo path, OS, etc.)
├── tracked.conf     # List of tracked paths
├── ignored.conf     # List of ignored patterns
└── deleted.conf     # Tombstone entries (path|timestamp)
```

### Repo Structure
```
$GITHUBPATH/dotfiler-ng/
└── $OS/
    └── files/
        ├── $HOME/...       # Home directory files
        └── /absolute/...   # Non-home files
```

### Rsync Strategy
1. **Track Deletions**: `rsync --delete --dry-run` to detect
2. **Include Files**: `--files-from=tracked.conf`
3. **Exclude Patterns**: `--exclude-from=ignored.conf`
4. **Preserve Attributes**: `-av` for permissions/timestamps
5. **Environment Variables**: Expand in bash before rsync call

### Deletion Management
- Automatic detection via rsync dry-run
- Tombstone system for cross-machine propagation
- 90-day active enforcement
- 120-day passive protection
- Auto-cleanup after 120 days

### Command Mapping
| Original | New Implementation |
|----------|-------------------|
| add | Add to tracked.conf |
| ignore | Add to ignored.conf |
| build | Two-phase rsync operation |
| delete | Add tombstone + remove files |
| list | Read tracked.conf |
| remove | Remove from tracked.conf |

## Implementation Progress
- Phase 1: Architecture design ✅
- Phase 2: Creating project structure (in progress)
- Phase 3-6: Pending

## Critical Implementation Notes
1. Must handle $HOME expansion before passing to rsync
2. Rsync requires trailing slashes for directory behavior
3. Use `--dry-run` for deletion detection without actual deletion
4. Store absolute paths for non-$HOME files in repo
5. Build process must check tombstones before syncing