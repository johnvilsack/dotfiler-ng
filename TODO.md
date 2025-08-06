# Dotfiler-NG Development TODO

## Project Overview
Building next-generation dotfiler using rsync as the core sync engine, replacing symlink-based approach with actual file copying.

## Phase 1: Architecture & Setup ✅
- [x] Analyze requirements and select rsync as backbone tool
- [x] Map out rsync-based architecture
- [ ] Create initial project structure
- [ ] Set up configuration management system

## Phase 2: Core Commands
- [ ] Implement `add` command for tracking files/folders
- [ ] Implement `ignore` command for exclusions
- [ ] Implement `list` command to show tracked items
- [ ] Implement `remove` command to untrack items

## Phase 3: Sync Operations
- [ ] Implement `build` command with bidirectional sync
  - [ ] Filesystem → Repo (new files only)
  - [ ] Repo → Filesystem (all tracked files)
- [ ] Implement `--repo-first` flag for fresh installs
- [ ] Handle .gitignore files as additional ignore sources

## Phase 4: Deletion Management
- [ ] Implement automatic deletion detection using rsync
- [ ] Create tombstone system for cross-machine deletion
- [ ] Implement deletion lifecycle (90 days active, 120 days passive)
- [ ] Handle deletions within tracked directories

## Phase 5: Advanced Features
- [ ] Machine-specific path configurations
- [ ] Auto-add new repo files to tracking
- [ ] Handle files outside $HOME directory
- [ ] Environment variable expansion in paths

## Phase 6: Testing & Documentation
- [ ] Create test scenarios in dotfiles-ng
- [ ] Test cross-machine deletion scenarios
- [ ] Test fresh install scenarios
- [ ] Update README with usage examples
- [ ] Document migration from original dotfiler

## Current Status
**Working on:** Creating initial project structure and architecture

## Notes
- Using rsync instead of rclone for better deletion detection and simpler filter format
- Maintaining compatibility with original dotfiler's config file formats
- Config location: `$HOME/.config/dotfiler/`
- Repo structure: `$GITHUBPATH/dotfiler-ng/$OS/files/`