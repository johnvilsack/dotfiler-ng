# Dotfiler-NG Revolutionary Rewrite

## Architecture Philosophy Change

### From: Conservative Wrapper
- Manual deletion commands
- Complex configuration management  
- User-driven operations
- Symlink compatibility issues

### To: Revolutionary Rsync Orchestrator
- **Automatic deletion detection** via `rsync --delete --dry-run`
- **Rsync does heavy lifting**, dotfiler orchestrates multi-machine coordination
- **Zero user intervention** for deletions (filesystem deletions auto-tracked)
- **Automatic symlink migration** to real files

## Core Operations Redesign

### 1. Sync Operation (`dotfiler sync`)
```bash
# Phase 1: Detect deletions automatically
rsync --delete --dry-run filesystem/ repo/ | grep "^deleting" → deleted.conf

# Phase 2: Filesystem → Repo (rsync with filters)  
rsync -av --filter-from=rsync_filters filesystem/ repo/

# Phase 3: Repo → Filesystem (rsync with deletion enforcement)
rsync -av --delete repo/ filesystem/

# Phase 4: Cross-machine deletion enforcement
for deleted in deleted.conf; do enforce_deletion(deleted); done

# Phase 5: Tombstone lifecycle management (90/120 day cleanup)
cleanup_tombstones_with_timestamps()
```

### 2. Automatic Deletion Flow
```
User deletes file in filesystem 
    ↓
Next sync detects via rsync --dry-run
    ↓  
Auto-adds to deleted.conf with timestamp
    ↓
Git propagates deleted.conf to other machines
    ↓
Other machines enforce deletion during sync
    ↓
120 days later: tombstone auto-removed
```

### 3. Rsync Filter Enhancement
- Convert ignored.conf to rsync filter format
- Merge .gitignore patterns into rsync filters
- Single rsync operation handles all include/exclude logic

### 4. Symlink Migration
- Detect existing symlinks during `--repo-first`
- Replace symlinks with real files
- Preserve all file attributes and permissions

## Configuration Simplification

### Kept (Enhanced)
- **tracked.conf**: Multi-directory/file tracking (rsync source list)
- **ignored.conf**: Patterns (converted to rsync filters)  
- **deleted.conf**: Cross-machine tombstones (auto-managed)

### Enhanced
- **rsync_filters**: Generated from ignored.conf + .gitignores
- **config**: Simplified with rsync-specific options

### Removed
- Manual deletion workflows
- Complex symlink handling
- Multi-phase sync complexity (rsync handles it)

## Benefits of Revolutionary Approach

1. **Automatic Everything**: No manual `dotfiler delete` needed
2. **Rsync Power**: Leverages mature, battle-tested sync engine
3. **Simplified Architecture**: Rsync does complex operations
4. **Better Performance**: Single rsync operations vs multiple steps
5. **Seamless Migration**: `--repo-first` fixes existing setups
6. **Same User Experience**: Enhanced capabilities, same interface

## Implementation Strategy

1. Rewrite sync.sh as revolutionary rsync orchestrator
2. Add automatic deletion detection
3. Enhance ignore system with rsync filters  
4. Add symlink migration capability
5. Update main executable (build → sync)
6. Preserve 120-day tombstone lifecycle exactly as original