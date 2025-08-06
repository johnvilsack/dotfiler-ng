# Dotfiler-NG

Next-generation dotfiles management with rsync backend, replacing symlink-based approach with actual file copying.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/johnvilsack/dotfiler-ng/refs/heads/main/install.sh | bash
```

## What's New in NG

### Core Improvements
- **No More Symlinks**: Copies actual files instead of creating symlinks
- **Rsync Backend**: Reliable, battle-tested synchronization with automatic deletion detection
- **Automatic Workflows**: Delete files normally - next sync detects and manages them
- **Better Ignore Support**: Direct .gitignore integration plus custom patterns
- **Fresh Install Mode**: `--repo-first` flag for clean installations and symlink migration

### Commands

| Command | Description | Example |
|---------|-------------|---------|
| `add <path>` | Add file/directory to tracking | `dotfiler add ~/.zshrc` |
| `remove <path>` | Remove from tracking | `dotfiler remove ~/.config/nvim` |
| `ignore <pattern>` | Add to ignore list | `dotfiler ignore "*.log"` |
| `delete <path>` | Delete and tombstone | `dotfiler delete ~/.config/old-app` |
| `sync` | Revolutionary rsync-powered sync | `dotfiler sync` |
| `sync --repo-first` | Fresh install mode | `dotfiler sync --repo-first` |
| `build` | Alias for sync (compatibility) | `dotfiler build` |
| `list` | Show tracked items | `dotfiler list` |
| `status` | Show sync status | `dotfiler status` |

### Architecture

```
Repository Structure:
$REPO_PATH/$OS/files/
├── $HOME/              # Home directory files  
└── /absolute/paths/    # Non-home files

Configuration:
~/.config/dotfiler/
├── config              # Main settings
├── tracked.conf        # Tracked paths
├── ignored.conf        # Ignore patterns  
└── deleted.conf        # Tombstone entries
```

### Sync Process

1. **Tombstone Lifecycle**: Manage 90/120-day deletion enforcement
2. **Symlink Migration**: Auto-convert existing symlinks to real files
3. **Deletion Detection**: Automatically detects filesystem deletions
4. **Unified Filtering**: Single rsync operation with combined ignore patterns
5. **Bidirectional Sync**: Filesystem ↔ Repository synchronization
6. **Cross-Machine Enforcement**: Git-propagated deletion coordination
7. **Auto-Discovery**: Automatically track new repository files

**Key Feature**: Just delete files normally - next `dotfiler sync` detects and manages everything!

### Migration from Original Dotfiler

Dotfiler-NG is backward compatible with original dotfiler configuration files. Your existing `tracked.conf`, `ignored.conf`, and `deleted.conf` will work as-is.

### Key Features

- ✅ **Cross-platform**: macOS, Linux, Windows (WSL)
- ✅ **Environment variables**: `$HOME` expansion in paths
- ✅ **Gitignore integration**: Respects .gitignore files as exclude sources
- ✅ **Tombstone system**: 90-day active deletion, 120-day passive protection
- ✅ **Arbitrary paths**: Sync files outside `$HOME` directory
- ✅ **Conflict detection**: Warns about ignore/track conflicts

### Requirements

- `rsync` (installed by default on macOS/Linux)
- `bash` 3.2+ (macOS default)
- `git` (for repository management)

### Development

Current status: **Feature Complete**
- All core functionality implemented
- Backward compatible with original dotfiler
- Ready for testing and production use

### Future Enhancements

- Machine-specific configuration profiles
- Enhanced path mapping capabilities
- Performance optimizations for large file sets
- Integration with cloud storage backends