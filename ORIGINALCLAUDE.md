We are going to remake the dotfiler application. I have selectd rclone as the primary tool to underpin this endeavor. I will need you build the bash architecture surrounding the commands dotfiler will issue to support it.

## Overview
For this project, I’ve given you root access to my entire GitHub. The only repos you need to work within are dotfiler, dotfiler-ng and dotfiles-ng. Dotfiler is the original piece of software and dotfiler-ng is where you will be writing new code. You should only be creating new files and folders within dotfiler-ng. dotfiles-ng is a repo copy of my dotfiles repo folder so you can see the structure and use it for testing. You can make changes in here but they should be ephemeral.

dotfiler-ng also contains a copy of the original source code in the original_source folder. WARNING: The code has NOT been refactored to reflect this change.

Dotfiler is a great program. It does much of what I want it to do. You can review the code, read the README.md, CHANGELOG.md, CLAUDE.md, and MEMORY.md to get a better understanding of what it’s doing and what it is capable of.

What I would like to explore is a potential rewrite of the software into a next-generation model. As a tool, it does exactly what we’ve asked it to do. However, filesystems and other applications do not all treat or honor symlinking the same, and it’s causing us headaches.

I’m wondering if there are better tools we can leverage to perform the overall functionality of what we are trying to accomplish. Here are the parameters I believe we may be seeking. You should expand this list if you think I am creating any gaps.

## Intended Goals of Software
1.The goal is to synchronize files and folders with a repo that can be safely backed up. 
2. We want to be able to synchronize folders, but we want to be able to exclude subfolders and files from being included. This will give us the flexibility to stash configuration and mutable files without the burden of potential logs, caches, and other data we don’t want being synced back to the repo. 
3. The dotfiles are used and managed between multiple machines the user is regularly jumping between. This means that we have to account for deletions, moves, copies, etc. Dotfiler has a tombstone mechanism in place currently but there are still user responsibilities that have to be considered
4. Order of precedence is important:
   1. Files
      1. File is listed explicit in tracked.conf
         1. tracking takes precendence over ignored.conf and .gitignore
         2. Deletion mechanic should have removed this file from tracking
      2. File is in a tracked directory AND
         1. The file or subfolder is not explicitly listed in ignored.conf
         2. The file, subfolder, or pattern is not explictly listed in a .gitignore at any point in its filepath.
         3. The file is not deleted (it should follow a deletion pattern)
5. Storage mechanism is important. The repo should eventually contain storage for potentially multiple hosts across a variety of filesystems as well as additional items like scripts, docs, etc. The current methodology is to employ a structure within $GITHUBPATH/<reponame>/$OS/files. Any folder not in $HOME path is treated as absolute value from the root of this /files folder.  $HOME is treated as living in HOME directory. Having this structure allows for files to be synced from outside the standard $HOME directory, which is a limitation of some dotfiles tools.
6. Directory sync should be additive in both directions. ignored files in the filesystem should not be manipulated.
7. Files and folders are saved with full path unless in $HOME directory. In those instances, we save with the envvar.

## Existing Functionality
1. Of the tools primary functions, the standard workflow for the user is primarily:
   1. dotfiler add to add new files or folders. Adding a directory does not create explicit entries for every subfile or subfolder. this is intentional for effective management.
   2. dotfiler ignore to explicitly list files or folders in ignored.conf.
   3. dotfiler build to perform various actions, primarily to perform the sync and buildout expected. This should also perform the maintenance of the three files (tracked, ignored, deleted), adding timestamps to deleted entries, etc.
   4. dotfiler delete to remove files from the filesystem and repo, and track them moving forward. Files will be actively deleted for the first 90 days after a deletion the entry removed after 120 days.
   5. a dotfiler build is performed during the inital install of a system with --repo-first. This enforces an overwrite of any tracked file or folder with the repo version, ignoring newer versions on the host filesystem. Rationale is that a base install may include configuration files that are slightly older but have value over potential default files that were installed during setup.
   6. A dotfiler build is executed during updates.
2. Existing functionality was built upon symlinking for management. We have discovered this creates many edge cases, so file and folder duplication is the preferred method.

## Considerations not implemented in original:
   1.  New folders and files that appear in the repo can/should be added to the filesystem and tracked in tracked.conf. Tracking should always track specific file if only a file has been added or a folder if the folder does not exist in the filesystem. (ask for clarity if this needs elaboration)
   2.  We should be able to set completely new paths for the specific machine. We are currently using $GITHUBPATH/dotfiler/$OS to store files and scripts. This reflects what I would consider to be my standard setup for a mac, but it's possible I may want other setups specific to a different host.

## Existing Architecture

The software was written in bash due to its extensive manipulation of the filesystem and its ability to glue existing functionality and tools together for usage. The intended installation is meant to be installed and made executable from the $HOME/.local/bin directory so that it remains accessible throughout the filesystem.

## The requirements for the tool

1. Ability to
   1. Sync files and folders in the same OS without an online component
   2. Do it from the command line?
   3. Set specific files and folders to include in a stored file
   4. Set specific files and subfolders to exclude in a stored file
   5. Treat .gitignores as additive to ignore lists
   6. Account for removals and management of multiple machines using the same source (managed through git)
   7. Assign arbitrary paths for both sides of the sync (i.e. no OneDrive)
   8. Account for new files or folders in the repo and add them accordingly
   9. Allow for "fresh install" with repo source taking precedence over existing structure in certain scenarios
   10. Live syncing a bonus but not necessary. Capable of running builds and commits manually.
2.  Store configuration of rclone in the same repo

## Phases of project
1. With rclone selected, what features need to be created in the new dotfiler to perform the actions we need it to perform. What features does rclone provide that we can utilize?
2. Map out requirements based on this document, additional .md review in original_source folder, and code analysis
3. Generate functionality in steps, using frequent commits
   1. Overall structure of source code and storage repo
   2. Account for adding files and folders to tracking
   3. Account for ignoring files and folders from tracking
   4. Account for regular syncing (between repo and filesystem)
   5. Account for first-time install syncing (overwrite filesystem)
   6. Account for deletions
   7. Account for cross-device management (specifically deletions)
4. Thoroughly test
5. Future state: what additional things can rclone do for us now?

## Programming Notes
1. Version specific coding per file as top comment.
2. Frequently commit your code
3. Use dotfiler-ng/TODO.md for listing all tasks. Keep record of what has been done, what you are working on, and what is coming next.
4. Use dotfiler-ng/MEMORY.md to store anything you need to remember in case your connection is lost, or a /compact fails.
5. You should use multiple agents if the tasks are capable of being broken up into different assignments.
   1. If you are able to break it down into agents, you will be the agent manager. Break the todos down into separate TODOs such as dotfiler-ng/AGENT1-TODO.md, dotfiler-ng/AGENT2-TODO.md and so on.
6. Develop code in a way that makes it easier to test individual components so that you are able to test functionality before moving on to the next task.

## Notes
1. I created a install.sh file and committed it to get the raw github link that can be used in the README for one click installation. Link is: [Here](https://raw.githubusercontent.com/johnvilsack/dotfiler-ng/refs/heads/main/install.sh)

