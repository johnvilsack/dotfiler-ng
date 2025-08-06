# Dotfiler

A powerful, cross-platform dotfiles management system with intelligent file tracking, ignore patterns, and enhanced logging.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/johnvilsack/dotfiler/HEAD/install.sh | bash
```

## What is Dotfiler?

Dotfiler is a sophisticated dotfiles management tool that helps you:
- **Track and sync** configuration files across machines
- **Manage complex directory structures** with selective ignore patterns  
- **Symlink management** for seamless file updates
- **Cross-platform support** (macOS, Linux)
- **Enhanced logging** with colorized output and syslog integration

## Core Features

### 🔗 **Intelligent Symlink Management**
- Automatically creates symlinks from your repository to system locations
- Handles both individual files and entire directories
- Smart conflict resolution and error handling

### 🚫 **Advanced Ignore System** 
- Gitignore-style pattern matching for files and folders
- Supports glob patterns like `*.log`, `.DS_Store`, `**/*.tmp`
- Retroactive ignore cleanup (removes already-tracked files)
- Prevents accidental tracking of sensitive files

### 🔄 **Automatic Sync & Build**
- `build` command auto-syncs new files before creating symlinks
- Handles nested directory structures intelligently
- Prevents directory loops and corruption

### 🎨 **Enhanced Logging (`clog`)**
- Colorized console output with timestamps
- Automatic syslog integration
- JSON output support for structured logging
- Cross-platform compatibility (macOS/Linux)

## Commands

| Command | Description | Example |
|---------|-------------|---------|
| `add` | Add files/directories to tracking | `dotfiler add ~/.zshrc` |
| `remove` | Remove and restore files from tracking | `dotfiler remove ~/.config/nvim` |
| `ignore` | Add files/patterns to ignore list | `dotfiler ignore "*.log"` |
| `unmanage` | Stop managing specific files (exact match) | `dotfiler unmanage ~/.bashrc` |
| `build` | Sync new files + create all symlinks | `dotfiler build` |
| `sync` | Copy new files to repository only | `dotfiler sync` |
| `cleanup` | Remove all ignored files from repository | `dotfiler cleanup` |
| `list` | Show all tracked files | `dotfiler list` |

## Usage Examples

### Basic Workflow
```bash
# Add configuration files
dotfiler add ~/.zshrc
dotfiler add ~/.config/nvim
dotfiler add ~/.gitconfig

# Build symlinks (auto-syncs new files first)
dotfiler build

# Add ignore patterns
dotfiler ignore .DS_Store
dotfiler ignore "*.log"
dotfiler ignore ~/.config/sensitive-data

# Check what's being tracked
dotfiler list
```

### Advanced Features
```bash
# Ignore entire directories with confirmation prompts
dotfiler ignore ~/.config/private
# [WARNING] Ignoring '$HOME/.config/private' would affect these tracked files:
#   - $HOME/.config/private/secret.txt
# This will stop managing these tracked files. Continue? (y/N): y

# Unmanage specific files (exact match required)
dotfiler unmanage ~/.config/nvim
# [WARNING] This will stop managing '/Users/user/.config/nvim' and restore it as a regular file/directory.
# Continue with unmanaging '/Users/user/.config/nvim'? (y/N): y

# Clean up repository
dotfiler cleanup
```

## Enhanced Logging with `clog`

Dotfiler includes `clog`, a standalone colorized logging utility:

```bash
# Basic usage
clog INFO "Application started"
clog WARNING "Disk space low" 
clog ERROR "Connection failed"
clog SUCCESS "Backup completed"

# With options
clog --timestamp INFO "Timestamped message"
clog --json ERROR "JSON formatted output"
clog --tag "my-app" WARNING "Custom syslog tag"
```

### `clog` Features:
- **6 log levels**: INFO, WARNING, ERROR, SUCCESS, DEBUG, TRACE
- **Colorized output**: Different colors for each level
- **Syslog integration**: Automatic logging with proper priorities
- **Flexible formatting**: JSON, timestamps, process IDs
- **Cross-platform**: Works on macOS and Linux
- **Environment aware**: Respects `NO_COLOR`, detects TTY

## File Structure

Dotfiler organizes files in your repository using this structure:

```
$DOTFILESPATH/
├── darwin/files/          # macOS files
│   ├── HOME/             # Files from $HOME
│   │   ├── .zshrc
│   │   └── .config/
│   │       └── nvim/
│   └── etc/              # System files (/etc/*)
└── linux/files/          # Linux files (same structure)
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOTFILESPATH` | Path to your dotfiles repository | `$HOME/.dotfiles` |
| `CLOG_TAG` | Default syslog tag for clog | `clog` |
| `NO_COLOR` | Disable colored output | (unset) |
| `CLOG_NO_SYSLOG` | Disable syslog logging | (unset) |

## Configuration Files

- **Tracking list**: `~/.config/dotfiler/tracked-folders.txt`
- **Ignore patterns**: `~/.config/dotfiler/ignore-list.txt`

## Advanced Use Cases

### Managing System Files
```bash
# Add system configuration (requires sudo for symlinks)
dotfiler add /etc/hosts
dotfiler build  # Will prompt for sudo when creating symlinks
```

### Selective Directory Management
```bash
# Track entire directory but ignore specific files
dotfiler add ~/.config
dotfiler ignore ~/.config/sensitive.key
dotfiler ignore "~/.config/**/*.log"
```

### Cross-Machine Sync
```bash
# On machine A
dotfiler add ~/.ssh/config
dotfiler build

# On machine B (with same DOTFILESPATH repo)
dotfiler build  # Automatically syncs and links files
```

## How Dotfiler Works: Order of Operations

Understanding how dotfiler processes files helps avoid common pitfalls:

### `dotfiler build` Process

**Phase 1: Cleanup** 🧹
- Removes any ignored files that are currently managed
- Cleans up broken symlinks automatically

**Phase 2: Sync New Files** 📥 *(unless `--repo-first`)*
```bash
# For each tracked item (from tracked-folders.txt):
1. ✅ Check ignore list → Skip if ignored
2. ✅ Check if exists on filesystem → Skip if missing
3. 🔍 Scan directories recursively:
   - ✅ Check each file against ignore list → Skip if ignored
   - 📋 Copy new files to repo (existing files skipped)
```

**Phase 3: Create Symlinks** 🔗
```bash
# For each file in repository:
1. ✅ Check ignore list → Skip if ignored
2. 🔗 Create symlink: filesystem_path → repo_file
3. ⚠️  Overwrites existing files with symlinks
```

### Key Behaviors

- **Triple Ignore Checking**: Ignore patterns checked at tracked-item, individual-file, and symlink levels
- **Individual File Symlinks**: Each file gets its own symlink (directories are never symlinked)
- **Repo Authority**: Build phase uses repository as source of truth
- **New Files Only**: Sync only copies files that don't exist in repo yet

## Safe File and Directory Management

### ❌ **Wrong Way** (Creates Problems)
```bash
# DON'T: Delete files directly - they'll recreate on other machines
rm ~/.config/some-app/unwanted-file.conf
dotfiler build  # File returns from repo!

# DON'T: Delete from repo directly - symlinks break
rm ~/.dotfiles/mac/files/HOME/.config/some-app/file.conf
# Now ~/.config/some-app/file.conf is a broken symlink
```

### ✅ **Right Way**: Proper Deletion Process

**✅ Recommended: Use `dotfiler delete` (New!)**
```bash
# Permanently delete with cross-system enforcement
dotfiler delete ~/.config/unwanted-app

# What this does:
# 1. Creates tombstone (prevents resurrection)
# 2. Adds to ignore list (prevents re-tracking)
# 3. Removes from repository
# 4. Removes from tracking (if directly tracked)
# 5. Deletes from current filesystem
# 6. Enforces deletion on other systems for 90 days
```

**Alternative: Manual Process (Old Way)**
```bash
# For individual files:
dotfiler remove ~/.config/some-app/unwanted-file.conf  # ⚠️ May fail if parent tracked
rm ~/.config/some-app/unwanted-file.conf

# For entire directories:
dotfiler remove ~/.config/some-app
rm -rf ~/.config/some-app
```

**To Stop Tracking But Keep Files:**
```bash
# Use unmanage - converts symlinks back to regular files
dotfiler unmanage ~/.config/some-app
# Files remain on filesystem as regular files
```

### 🚨 **Edge Cases and Multi-Machine Scenarios**

**Problem**: Files deleted on Machine A recreate from repo on Machine B
```bash
# Machine A: Delete file incorrectly
rm ~/.config/app/file.conf  # Oops! File still in repo

# Machine B: Next build
dotfiler build  # File recreates from repo!
```

**Solution**: Always use `dotfiler remove` first
```bash
# Machine A: Proper deletion
dotfiler remove ~/.config/app/file.conf
rm ~/.config/app/file.conf

# Machine B: Next build  
dotfiler build  # File stays gone - not in repo anymore
```

**Pro Tip**: Use `dotfiler list` to see what's currently tracked before making changes.

## Advanced Deletion Management

Dotfiler now includes a sophisticated deletion system with **tombstoning** to handle the "parent directory problem" and ensure deletions work correctly across multiple machines.

### The Problem Solved

**Before**: If you tracked `~/.config/kitty` and later wanted to delete just `unwanted.conf`:
```bash
# ❌ This failed - couldn't remove individual files from tracked directories
dotfiler remove ~/.config/kitty/unwanted.conf  # Error: not tracked individually
rm ~/.config/kitty/unwanted.conf               # File resurrects on next build!
```

**Now**: Use `dotfiler delete` for bulletproof deletion:
```bash
# ✅ This works perfectly
dotfiler delete ~/.config/kitty/unwanted.conf
# Works even though ~/.config/kitty is tracked as a directory
```

### New Configuration Files

Dotfiler now uses three configuration files (auto-migrates from old format):
- **`tracked.conf`** - Items being actively managed
- **`ignored.conf`** - Items to permanently ignore
- **`deleted.conf`** - Deletion tombstones with timestamps

### Cross-Machine Deletion Enforcement

**Scenario**: Delete file on Machine A, sync to Machine B
```bash
# Machine A
dotfiler delete ~/.config/unwanted-app

# Machine B (runs build within 90 days)
dotfiler build
# [WARNING] Enforcing deletion on this system: ~/.config/unwanted-app
# File automatically removed on Machine B too!
```

### Tombstone Lifecycle

| Days Since Deletion | Behavior |
|---------------------|----------|
| **0-90 days** | 🚫 **Active Enforcement** - Deleted on any system that runs build |
| **90-120 days** | 🛡️ **Passive Protection** - Ignored if found, but not actively deleted |
| **120+ days** | 🧹 **Auto-Cleanup** - Tombstone removed if file doesn't exist |

### Advanced Use Cases

**Delete files within tracked directories:**
```bash
dotfiler add ~/.config/kitty              # Track directory
dotfiler delete ~/.config/kitty/debug.log # Delete specific file - works!
```

**Handle automated files that keep returning:**
```bash
dotfiler delete ~/.config/app/cache.db
# If file keeps reappearing, tombstone stays active indefinitely
# ensuring it's always ignored
```

**Clean deletion across team/multiple machines:**
```bash
# Team member adds unwanted file
git pull  # Gets the deletion tombstone
dotfiler build  # Automatically removes unwanted file locally
```

## Installation Options

### Standard Installation
```bash
curl -fsSL https://raw.githubusercontent.com/johnvilsack/dotfiler/HEAD/install.sh | bash
```

### Development/Testing Installation
```bash
git clone https://github.com/johnvilsack/dotfiler.git
cd dotfiler
./test.sh  # Installs from local repository
```

## Compatibility

- **Operating Systems**: macOS (10.12+), Linux (most distributions)
- **Shells**: bash, zsh, fish (command-line usage)
- **Requirements**: Standard UNIX tools (find, ln, cp, mkdir, etc.)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test with `./test.sh`
4. Submit a pull request

## Troubleshooting

### Common Issues

**Environment not set**:
```bash
export DOTFILESPATH="$HOME/.dotfiles"
```

**Permission issues**:
```bash
# Ensure proper permissions
chmod +x ~/.local/bin/dotfiler
chmod +x ~/.local/bin/clog
```

**Path issues**:
```bash
# Add to shell profile
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

## License

MIT License - see LICENSE file for details.