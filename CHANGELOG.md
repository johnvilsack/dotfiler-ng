# Changelog

## [3.0.0] - 2025-08-05
### Added
- **New `delete` command**: Permanent file deletion with cross-system enforcement
- **Tombstoning system**: Prevents deleted files from being resurrected on other machines
- **Advanced deletion management**: Handles files within tracked directories that weren't individually tracked
- **Configuration migration**: Auto-migrates from old single-file config to new multi-file system (`tracked.conf`, `ignored.conf`, `deleted.conf`)
- **Deletion lifecycle**: 90-day active enforcement, 120-day passive protection, automatic cleanup

### Changed
- Major refactoring of configuration file handling
- Updated README with comprehensive deletion management documentation
- Enhanced build process to handle tombstone enforcement

### Technical Details
- 350 lines added to new `delete.sh` module
- Updated all core modules to support new configuration system
- Improved error handling and user prompts

## [2.0.1] - 2025-08-05
### Fixed
- **Critical fix**: Broken symlinks were causing build crashes
- Improved symlink validation in build process
- Enhanced error handling in sync operations

### Changed
- Major README expansion with comprehensive documentation
- Better handling of edge cases in file operations
- Improved logging and debugging capabilities

## [2.0.0] - 2025-08-05
### Added
- **`--repo-first` flag**: Revolutionary new build mode for fresh installations
  - Prioritizes repository files over filesystem files
  - Essential for clean setups on new machines
  - Prevents conflicts during initial sync
- Current state tracking files for debugging (`current-ignorelist.txt`, `current-trackedfolders.txt`)

### Changed
- Enhanced build logic to handle fresh installs intelligently
- Improved sync behavior with new repository-first option
- Local installer improvements

### Technical Details
- Modified `build.sh` and `newsync.sh` for new installation flow
- Added command-line argument parsing

## [1.0.1] - 2025-08-05
### Added
- **Local installer**: `install-local.sh` for development and testing
- Enhanced installation options for different use cases

### Fixed
- Installation script improvements
- Better local development workflow

## [1.0.0] - 2025-08-05
### 🎉 **Production Release**
First stable release of dotfiler after extensive development and testing.

### Core Features Stabilized
- **File tracking and syncing**: Add, remove, and manage dotfiles across systems
- **Intelligent symlink management**: Individual file symlinks with conflict resolution
- **Advanced ignore system**: Gitignore-style patterns with retroactive cleanup
- **clog integration**: Colorized logging with syslog support
- **Cross-platform support**: macOS and Linux compatibility
- **Robust error handling**: Safe operations with comprehensive validation

### Major Components
- Complete dotfiler CLI with all core commands (`add`, `remove`, `build`, `sync`, `list`, `ignore`)
- Full clog logging utility with colorization and syslog integration
- Comprehensive documentation and README
- Installation system with remote fetch capability

---

## Pre-1.0.0 Development History

### Phase 4: Cleanup and Stabilization (July 27 - August 5, 2025)
#### [908bdae] Moved clog to macapps. Cleanup
- Removed development artifacts and temporary files
- Cleaned up clog-related files (moved to external macapps project)
- Removed PowerShell version, test files, and debug scripts
- **Files removed**: 726 lines across 8 files including `clog.ps1`, `demo_clog.sh`, `test.sh`

### Phase 3: Advanced Features Development (July 25-26, 2025)
#### [acd4adb] clog made - **Major Feature Addition**
- **Added complete clog logging utility** (231 lines)
- Colorized console output with 6 log levels (INFO, WARNING, ERROR, SUCCESS, DEBUG, TRACE)
- Automatic syslog integration with proper priority mapping
- Cross-platform support with environment detection
- JSON output format support
- **Major README expansion**: 226 new lines of comprehensive documentation
- Enhanced common.sh with 76 lines of logging utilities
- Added PowerShell version (`clog.ps1`) for Windows compatibility
- Demo scripts and comprehensive testing framework

#### [e9a9e5f] working! - Ignore System Completion
- Completed ignore functionality implementation (38 lines in build.sh)
- Major ignore.sh enhancements (70 lines added)
- Full integration testing and validation

#### [7728586] ignore logic - **Core Ignore System**
- **Massive ignore system implementation**: 372 lines added to ignore.sh
- Added ignore command to main dotfiler CLI (6 lines)
- Enhanced add.sh with ignore checking (9 lines)
- Implemented gitignore-style pattern matching
- Recursive directory scanning with ignore pattern application
- Retroactive cleanup of ignored files

#### [c1ed06d] added ignore functionality - **Ignore Foundation**
- **Initial ignore system**: Created ignore.sh (78 lines)
- Added ignore command to dotfiler CLI
- Integration with build and sync processes
- .gitignore creation for repository

### Phase 2: Core Feature Development (July 7-25, 2025)
#### [37510bc] added remove command - **Major Feature**
- **Complete remove functionality**: 130-line remove.sh implementation
- Added remove command to CLI
- File restoration and symlink management
- Safe removal with validation and error handling
- Added combine-script.sh utility (20 lines)

#### [9408b7e] added remove feature - Enhanced Remove
- Expanded remove functionality (44 additional lines)
- Improved error handling and edge case management

#### [f414ccf] fixed disappearing files
- Critical bug fix in remove.sh (20 lines modified)
- Resolved file restoration issues

#### [6310aa7] fixed dosync
- Sync system improvements in list.sh and sync.sh
- Better file enumeration and tracking

### Phase 1: Foundation and Initial Development (June 29 - July 7, 2025)
#### [3cf79f7] init - **Major Restructure**
- **Complete rewrite**: New modular architecture with dotfiler-lib/
- **Core modules implemented**:
  - `add.sh` (84 lines): File addition and tracking
  - `build.sh` (72 lines): Symlink creation and management  
  - `sync.sh` (29 lines): File synchronization
  - `list.sh` (19 lines): Tracked file enumeration
  - `newsync.sh` (42 lines): Enhanced sync operations
  - `common.sh` (22 lines): Shared utilities
- **New main executable**: dotfiler (95 lines) with command routing
- Moved old implementation to archive (old/ directory)
- Updated installation system and README

#### [6b1ff56] added claude's recommendations - **Initial Implementation**
- **First working version**: Complete dotfiles management system
- **Core components** (510 lines total):
  - `bin/dotfiler` (90 lines): Main CLI interface
  - `lib/add.sh` (61 lines): File addition logic
  - `lib/common.sh` (64 lines): Shared utilities and path handling
  - `lib/link.sh` (117 lines): Symlink creation and management
  - `install.sh` (31 lines): Remote installation script
- **Original functions** preserved in separate directory
- Added project documentation (CLAUDE.md, README.md)

#### [4e88534] Initial commit
- Repository initialization with .gitattributes
- Basic project structure

---

### Development Insights

**Total Development Timeline**: ~5 weeks (June 29 - August 5, 2025)

**Major Development Phases**:
1. **Foundation** (Week 1): Core architecture and basic functionality
2. **Feature Expansion** (Weeks 2-3): Remove command, ignore system, advanced features  
3. **Polish & Integration** (Week 4): clog integration, testing, documentation
4. **Production Release** (Week 5): Stabilization, cleanup, versioning system

**Code Growth**:
- Started with basic dotfile management (~500 lines)
- Grew to production system (~2000+ lines)
- Major feature additions: ignore system (400+ lines), clog utility (300+ lines), deletion system (350+ lines)

**Key Technical Decisions**:
- Modular architecture with dotfiler-lib/ separation
- Individual file symlinks vs directory symlinks
- Gitignore-style ignore patterns
- Cross-platform compatibility focus
- Comprehensive logging and error handling


