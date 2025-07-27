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