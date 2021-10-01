# SNAPDIR
<pre>

  _________ _______      _____ __________________  ._____________ 
 /   _____/ \      \    /  _  \\______   \______ \ |   \______   \
 \_____  \  /   |   \  /  /_\  \|     ___/|    |  \|   ||       _/
 /        \/    |    \/    |    \    |    |    `   \   ||    |   \
/_______  /\____|__  /\____|__  /____|   /_______  /___||____|_  /
        \/         \/         \/                 \/            \/ 
                                        

</pre>
SNAPDIR is an ITOps/DevOPS bash script tool to compare directories, it allows you to take a snapshot of a directory, capturing the md5 hash, permission, owner and user group of the files in that directory and save those informations into a file which can then later be used to check for changes in that directory or a corresponding remote deployment. SNAPDIR only uses bash and GNU standard utils meaning on most linux systems it does not require dependency installation, you only need to copy the script to run it.


<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#getting-started">Getting Started</a>
    </li>
    <li><a href="#regex">Using with Regex</a></li>
    <li><a href="#verbosity">Veribosity Levels</a></li>
    <li><a href="#subfolders">Comparing subfolders</a></li>
    <li><a href="#advanced">Advanced</a></li>
    <li><a href="#manual">Manual</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## Getting-Started

1. Save a snapshot of directory xplorer into file savefile01

./snapdir.sh -a DUMPDIR -f savefile01 -d xplorer
![terminal](https://github.com/Hairi81/SNAPDIR/blob/main/wiki_images/dumpdir_wiki.gif?raw=true)

2. Compare snapshot file savefil01 against directory xplorer

./snapdir.sh -a CHECKDIR -f savefile01 -d xplorer
![terminal](https://github.com/Hairi81/SNAPDIR/blob/main/wiki_images/checkdir_wiki.gif?raw=true)


3. Print the directory structure of snapshot file savefile01

./snapdir.sh -a PRINTFILE -f savefile01
![terminal](https://github.com/Hairi81/SNAPDIR/blob/main/wiki_images/printfile_wiki.gif?raw=true)


## Regex
4. To only compare files with .js extensions

./snapdir.sh -a CHECKDIR -f savefile01 -d xplorer -g '\.js'

5. To exclude .js files from comparison

./snapdir.sh -a CHECKDIR -f savefile01 -d xplorer -g '\.js' -i

## Verbosity
6. To only display warning messages or above and disable progress bar [-s]

./snapdir.sh -a CHECKDIR -f savefile01 -d xplorer -g '\.js' -i -v WARN -s

Message Levels : 
DEBUG : Debugging messages
INFO : Normal operations including file matches
WARN : Permissions and or ownership missmatch
ERROR : Checksum missmatch or file not found


## Subfolders
7. To Compare directory mysources to subfolder src in savefile01

./snapdir.sh -a CHECKDIR -f savefile01 -d mysources -b /src 


## Advanced
You can edit the snapshot file with any text editor to add or remove specific items, use a leading # to comment a line. Below are helper file operations supported from the snapdir script.

8. Move the directory in the snapshot file savefile01, src to backup_src

./snapdir.sh -a MOVEDIR -f savefile01 -d /src -b /backup_src

Note the use of leading "/" to indicate the directory is located in the root of the snapshot file, using without a leading slash will move every directory and subdirectory in the snapshot file named src xplorer to backup_xplorer

9. Move all files in the directory src in the snapshot file savefile01, having the extension .js to backup_js

./snapdir.sh -a MOVEFILES -f savefile01 -d /src -b /backup_js -g '\.js'

This operation will flatten the directory structure into backup_js


## Manual
<pre>
Usage: /home/hairi/bashlab/snapdir.sh -a ACTION -f FILENAME -d DIRECTORY
   -a ACTION        action flag, specifies the type of action to be performed
                          DUMPDIR  : dump directory list of files DIRECTORY into file FILENAME
                          CHECKDIR : compare supplied file list FILENAME against directory DIRECTORY
                          PRINTFILE : print FILENAME directory structure
                          MOVEDIR : in filelist, move FILENAME directory from -d DIRECTORY to -b DIRECTORY2
                          DELETEDIR : in filelist, delete directory DIRECTORY from FILENAME
                          MOVEFILES : in filelist, move files from -d DIRECTORY to -b DIRECTORY with the -g
                                      regexpattern
                          DELETEFILES : in filelist, delete files in -d DIRECTORY with the -g regexpattern
   -f FILENAME       filename to be used for the actions specified, default is filelist
   -d DIRNAME        directory in which the action is to be performed, default is .
   -g REGEX          regex pattern for file to be include, default is '*.' which includes all files
   -s                silentmode, disables progress bar, useful for piping
   -v LEVELS         verbosity levels : DEBUG, INFO, WARN, ERROR
   -i                invert regex matching pattern of -g regex
   -b DIRNAME        rebase to subfolder
</pre>

## Contact
Email me at hairi.abass@gmail.com

