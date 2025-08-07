! Important notice: Since the creation of the POST-COMPACT-PLAN.md, I have learned that rsync does not expand variables. This means that files and folders located in the HOME directory should be sourced with ~ versus $HOME. This may have been the cause of many problems.

## dotfiler-ng Using rsync Behavior and Logic (Simplified)

Wrapper application for rsync that adds persistent tracking of files and folders, ignoring of subfiles and subfolders when tracking whole folders, tracking the deletion of objects and tombstoning them for cross device synchronization. Leverage rsync as much as possible, building highly performant and minimalistic functions in bash to support the process. 

### 1. Required Files

* `config` – general settings (paths)
  * DefaultRepo = $DOTFILESPATH (equal to ~/github/dotfiles)
  * RepoFilesLocation = <DefaultRepo>/mac/files
  * RepoHOMEDirectory = <DefaultRepo>/mac/files/HOME
  * Any path outside HOME = <DefaultRepo>/mac/files/<fullpath> 
* `tracked.conf` – list of tracked files/folders
* `ignored.conf` – ignore patterns
* `deleted.conf` – tombstones with timestamps
* Location of configs - $HOME/.config/dotfiler/
* NOTE: All files and functions working with entries MUST be capable of supporting envvar paths.
* NOTE: Any file in $HOME path must be entered using $HOME envar, not absolute path!

---

### 2. Allowed Commands

* `track <path>` → add to `tracked.conf`
* `ignore <pattern>` → add to `ignored.conf`
* `delete <path>` → add to `deleted.conf`, remove from FS and repo
* `sync [--repo-first]` → core function
* `list` → show all tracked paths
* `status` → show config and sync health

---

### 3. Directional Logic

#### First-Time Install (`sync --repo-first`)

* Repo → Filesystem only
* Overwrite all matching paths
* No FS → Repo sync
* Replace symlinks with real files

#### Normal Sync (`sync`)

1. Filesystem deletions → update `deleted.conf`
2. Filesystem → Repo (new or updated tracked files only)
3. Repo → Filesystem (tracked files only)
4. Enforce deletions from `deleted.conf`
5. Cleanup expired tombstones (after 120 days)

---

### 4. Sync Function (Exact Steps)

#### If `--repo-first`:

1. Cleanup ignored and deleted files
2. Replace symlinks with real files
3. Copy all repo files to filesystem
4. Skip FS → Repo sync

#### Else (normal sync):

1. Detect deletions with `rsync --delete --dry-run`

   * Add missing tracked files to `deleted.conf` with timestamp
2. Sync FS → Repo

   * Include: entries from `tracked.conf`
   * Exclude: matches in `ignored.conf` and `.gitignore`
3. Sync Repo → FS

   * Include: only tracked files
   * Enforce deletions: remove anything in `deleted.conf`
4. Tombstone cleanup

   * Keep active for 90 days (enforced)
   * Keep passive for 30 more days (ignored)
   * Remove after 120 days
