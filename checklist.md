1. Are tracked files and folders being tracked and are you able to add new entries?
2. Are ignored files and folders being tracked and are you able to add new entries
3. Are deleted files and folders being tracjed and will they be automatically discovered and added?
4. Are the configuration files processed so that rsync is provided real paths and not variables?
5. Are files in the $HOME or ~ path synchronized to the HOME directory in the repo's files location?
6. Are other paths saved to the same directory but not in HOME?
Is bidirection synchronization functional?
   1. Will files and folders from the repo synchronize to the filesystem?
   2. Will files and folders from the filesystem synchronize with the repo?
   3. Are we comparing the files to ensure the newest one is the correct one to win?
   4. Are we actively ignoring files and folders from the config file?
5. Is ths system processing deletions?
   1. Are deletions in the repo being recognized?
   2. Are deletions in the filesystem being recognized?
   3. Are deletions in both cases being added to the deletion list?
   4. Are deletions being added to the ignore list?
   5. Are deletions in both cases deleting the file from the other side properly?
   6. Are deletions being added to the deletions list?
   7. Is the deletions list tracking and searching to delete all entries for 90 days from their timestamp?
   8. Is the deletions list holding on to those deletion records until 120 days then removing them?
   9. Will deletions being removed on the 120th day also delete the record from the ignored list?
6.  Hierarchy of Priority for normal synchronization:
    1.  SYNC ALL FILES AND FOLDERS FROM THE REPO TO THE FILESYSTEM WHEN
        1.  FILE OR FOLDER IS NOT SET TO BE DELETED (IN WHICH CASE DELETE)
        2.  FILE OR FOLDER IS NOT SET TO BE IGNORED
        3.  FILE OR FOLDER IS IN THE REPO BUT NOT IN THE FILESYTEM
        4.  FILE OR FOLDER IS NEWER IN THE REPO THAN IN THE FILESYSTEM
    2.  SYNC ALL FILES AND FOLDERS FROM THE FILESYSTEM TO THE REPO WHEN
        1.  FILE OR FOLDER IS NOT SET TO BE DELETED (IN WHICH CASE DELETE)
        2.  FILE OR FOLDER IS NOT SET TO BE IGNORED
        3.  FILE OR FOLDER IS IN THE FILESYSTEM BUT NOT IN THE REPO
        4.  FILE OR FOLDER IS NEWER IN THE FILESYSTEM THAN IN THE REPO
7. --repo-first
    1.  FILE OR FOLDER IS NOT SET TO BE DELETED (IN WHICH CASE DELETE)
    2.  FILE OR FOLDER IS NOT SET TO BE IGNORED
    3.  FILE OR FOLDER IS IN THE REPO
    4.  ALWAYS WRITE FILE OR FOLDER IN REPO
8. Layout
  1. Repo's files directory is root (e.g. /Users/johnv/github/dotfiles/mac/files)
    2. default value in configs should be path: $DOTFILESPATH/mac with /files being directory
  2. files contains
    1. HOME directory - Contains all files and folders to be synchonized to the $HOME or ~ directory
    2. Any path not in HOME path is saved fully here
9. Does dotfiler add work?
10.Does dotfiler ignore work?
11. Does dotfiler sync work?
12. Does dotfiler sync --repo-first work?
