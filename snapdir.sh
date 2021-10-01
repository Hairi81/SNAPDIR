#!/bin/bash
#SNAPDIR
#Directory comparison script for ITOps/DevOPS
#version 1.5, 29 September 2021
#this bash script compares files between a snapshot file and a directory


#Default variable values
default_permissions="644"
default_owner="root"
default_group="root"

tmpFilename="tmp.ABDB"

filename="filelist"
directory="."
regexstring='*.'
verbose='INFO'

rebase=''
silentmode='false'

#set -e

combkey=''


invertgrep=''

replacerebase='false'


#exec 2> /dev/null

#echo $key $value

print_usage() {

    echo "Filelist Utility Script for 1rstWAP deployers"
    echo "version 1.0"
    echo "This bash script diff files between a list and a directory using an inclusive regex pattern"
    echo "Usage: $0 -a [ACTION] -f [filename] -d [directory] "
    echo "   -a [ACTION]        action flag, specifies the type of action to be performed         "
    echo "                          DUMPDIR  : dump directory list of files [directory] into file [filename]                       "
    echo "                          CHECKDIR : compare supplied file list [filename] against directory [directory]           "
    echo "                          PRINTFILE : print [filename] directory structure            "
    echo "                          MOVEDIR : in filelist, move [filename] directory from -d [directory] to -b [DIR2]            "
    echo "                          DELETEDIR : in filelist, delete directory [directory] from [filename]            "
    echo "                          MOVEFILES : in filelist, move files from -d [directory] to -b [DIR2] with the -g regexpattern           "
    echo "                          DELETEFILES : in filelist, delete files in -d [directory] with the -g regexpattern  "
    echo "   -f [FILENAME]       filename to be used for the actions specified, default is filelist                         "
    echo "   -d [DIRNAME]        directory in which the action is to be performed, default is .                         "
    echo "   -g [REGEX]          regex pattern for file to be include, default is '*.' which includes all files      "
    echo "   -s                  silentmode, disables progress bar, useful for piping         "
    echo "   -v [LEVELS]         verbosity levels : DEBUG, INFO, WARN, ERROR         "
    echo "   -i                  invert regex matching pattern of -g regex        "
    echo "   -b [DIRNAME]        rebase to subfolder         "
    
    echo "Examples : "
    echo "  Dump directory bashlab to file dirfilelist"
    echo "   $0 -a DUMPDIR  -d bashlab -f dirfilelist"
    echo "  Check listfile dirfilelist against directory bashlab"
    echo "   $0 -a CHECKDIR  -d bashlab -f dirfilelist"
        
        
    exit




}

if [ $# -lt 3 ]
then
    print_usage

    exit
fi

#flag_generate=${4:-"NOGENERATE"}

unset filelist01
unset filelist01_md5
unset filelist02
unset filelist02_md5



declare -A filelist01
declare -A filelist01_md5
declare -A filelist01_permissions
declare -A filelist01_owner
declare -A filelist01_group

declare -A filelist02
declare -A filelist02_md5
declare -A filelist02_permissions
declare -A filelist02_owner
declare -A filelist02_group

declare -A tmparray

redvid="\0033[0;31m"
yellowvid="\0033[33m"
greenvid="\0033[0;32m"
lightredvid="\0033[1;31m"
resetvid="\0033[0m"


declare -A levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
declare -A levels_ctr=([DEBUG]=0 [INFO]=0 [WARN]=0 [ERROR]=0)
script_logging_level="INFO"



logThis() {

    
    local log_message=$1
    local log_priority=$2

     (( levels_ctr[$log_priority]++ ))

    #check if level exists
    [[ ${levels[$log_priority]} ]] || return 1

    #check if level is enough
    (( ${levels[$log_priority]} < ${levels[$script_logging_level]} )) && return 2

    #log here
    echo -e "${log_priority} : ${log_message}"

   

}

function ProgressBar {

if [[ $silentmode == "true" ]]
then
    return 1

fi

# Process data
    let _progress=(${1}*100/${2}*100)/100
    let _done=(${_progress}*4)/10
    let _left=40-$_done
# Build progressbar string lengths
    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")

# 1.2 Build progressbar strings and print the ProgressBar line
# 1.2.1 Output example:                           
# 1.2.1.1 Progress : [########################################] 100%
printf "\rProgress : [${_fill// /#}${_empty// /-}] ${_progress}%% $1"

}

check_DirExist()
{

if [[ ! -d "$1" ]] 
then
    
    echo "Directory $1 doesn't exist"

    exit -1


fi

}

check_FileExist()
{

if [[ ! -f "$1" ]] 
then
    
    echo "File $1 doesn't exist"

    exit -1


fi

}


check_FileAttributes()
{

    prefix01="File"

    if [ $md5a == "DIRECTORY" ]
        then
        prefix01="Directory"
    fi

    if [ $permissions_a != $permissions_b ]
         then

        logThis "${yellowvid}$prefix01 $key permission miss-match $permissions_a vs $permissions_b  ${resetvid}" "WARN"

        ((ctrDiff++))
      fi

    if [ $owner_a != $owner_b ]
         then

        logThis "${yellowvid}$prefix01 $key owner miss-match $owner_a vs $owner_b  ${resetvid}" "WARN"

      
          ((ctrDiff++))
      
      fi

    if [ $group_a != $group_b ]
         then

        logThis "${yellowvid}$prefix01 $key group miss-match $group_a vs $group_b  ${resetvid}" "WARN"
         
          ((ctrDiff++))
      fi
}

prompt_FileExist()
{

  if test -f "$1"; then
    echo "$1 already exists, do you wish to continue (A is append) ? [Y/N/A]"
    decision="N"    
    read  -n 1 -r
        echo    # (optional) move to a new line
        
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            decision="Y"
            return 1
        fi

        if [[ $REPLY =~ ^[Aa]$ ]]
        then
            decision="A"
            return 2
        fi

        if [ $decision == "N" ]; then
            exit 1
            

        fi


    fi
    return 0

}

move_FileDir()
{

if [[ $2 == "" ]]
then

echo "MOVEDIR -b destination directory cannot be empty"

exit -1


fi

create_DirIfNotExist $rebase $filename



echo "Moving filelist Dir from $1 to $2"
#echo "" > $filename".rebase"


#Handle case for non root folders checking the prefix /
firstchar=${1:0:1}
firstchar2=${2:0:1}

egrep1=""
egrep2=""

pDir=""
pDir2=""


#echo "firstchar is $firstchar"
if [[ $firstchar == "/" ]]
then
    strsize=${#1}

    if [[ $strsize > 1 ]]
    then 
        pDir="${1:1:strsize}"    
        #create_DirIfNotExist $pDir $filename
    else
        pDir=""
    fi
    egrep1="^$pDir"
else
    pDir=$1
        #create_DirIfNotExist $pDir $filename

    egrep1=".*$pDir"

fi


if [[ $firstchar2 == "/" ]]
then
    strsize2=${#2}

    echo "strsize 2 : $strsize2"


    if [[ $strsize2 > 1 ]]
    then 
        pDir2="${2:1:strsize2}/"
        pDir=".*$pDir"    
    else
        echo "here in pDir2"
        pDir2=""
        pDir=".*$pDir"    
    
    fi
    egrep2="^$pDir2"
else
    pDir2="$2/"
    #pDir=$1  
  

    egrep2="$pDir2"

fi


 if [[ $strsize2 > 1 && $strsize > 1 ]]
 then
#    cat $filename | egrep $invertgrep $regexstring |  egrep $egrep1 | sed -E "s|$pDir/|$pDir2|;s|$pDir\;|$pDir2\;|" > $filename".rebase"
    cat $filename |  egrep $egrep1 | sed -E "s|$pDir/|$pDir2|;s|$pDir\;|$pDir2\;|" > $filename".rebase"

 elif [[ $strsize2 > 1 && $strsize == 1 && $firstchar = "/" ]]
then
#    cat $filename | egrep $invertgrep $regexstring |  egrep $egrep1 | sed -E "s|^|$pDir2|" > $filename".rebase"

     cat $filename |   egrep $egrep1 | sed -E "s|^|$pDir2|" > $filename".rebase"

 else
  #  cat $filename | egrep $invertgrep $regexstring |  egrep $egrep1 | sed -E "s|$pDir/|$pDir2|" > $filename".rebase"
  cat $filename |  egrep $egrep1 | sed -E "s|$pDir/|$pDir2|" > $filename".rebase"

 fi


cat "$filename.rebase" |  sed "s|/;|;|" >> "$filename.rebase2"



cat $filename | egrep -v $egrep1 > $tmpFilename


sort -u -t";" -k1,1 -o "$filename.rebase2"{,}


opSize=$(cat "$filename.rebase2" | wc -l)

echo "Total $opSize items moved"
cat "${filename}.rebase2" >> $tmpFilename

#sort -o $filename{,}
sort -u -t";" -k1,1 -o $tmpFilename{,}


rm "${filename}.rebase"
rm "${filename}.rebase2"

rm $filename
cp $tmpFilename $filename







}

create_DirIfNotExist()
{
c_folder=$1
c_filename=$2


IFS='/' tokensDir=( $1 )

IFS=" "

arrSize1=${#tokensDir[@]}


c_tmpStr01=""

for (( i=0; i<${arrSize1}; i++ ));
do

    if [[ $i > 1 ]]
    then
        c_tmpStr01=$c_tmpStr01"/"${tokensDir[$i]}
   
    elif [[ $i > 0 && ${tokensDir[0]} != "" ]]
    then
     c_tmpStr01=$c_tmpStr01"/"${tokensDir[$i]}
   
    
    else
        c_tmpStr01="${tokensDir[$i]}"
    fi

    if [[ $c_tmpStr01 != "" ]]
    then
        c_tmpRes01=$(cat $c_filename | grep "DIRECTORY" | grep $c_tmpStr01)
    fi



if [[  $c_tmpRes01 == ""  && $c_tmpStr01 != "" ]]
then

    echo "$c_tmpStr01;DIRECTORY;644;default;default" >> $c_filename

fi



    
done



}

move_Files()
{

if [[ $2 == "" ]]
then

echo "MOVEFILES -b destination directory cannot be empty"

exit -1


fi

#create_DirIfNotExist
create_DirIfNotExist $rebase $filename


echo "Moving files from $1 to $2 with regex $regexpattern"


#Handle case for non root folders checking the prefix /
firstchar=${1:0:1}
firstchar2=${2:0:1}

egrep1=""
egrep2=""

pDir=""
pDir2=""


#echo "firstchar is $firstchar"
if [[ $firstchar == "/" ]]
then
    strsize=${#1}

    if [[ $strsize > 1 ]]
    then 
        pDir="${1:1:strsize}"    
    else
        pDir=""
    fi
    egrep1="^$pDir"
else
    pDir=$1
    egrep1=".*$pDir"

fi

if [[ $firstchar2 == "/" ]]
then
    strsize2=${#2}

    if [[ $strsize2 > 1 ]]
    then 
        pDir2="${2:1:strsize2}/"
        pDir=".*$pDir"    
    else
        pDir2=""
        pDir=".*$pDir"    
    
    fi
    egrep2="^$pDir2"
else
    pDir2="$2/"
    pDir=$1  
  

    egrep2="$pDir2"

fi

invertgrep2=""

if [[ $invertgrep == "-v" ]]
then
    invertgrep2=""
else
    invertgrep2="-v"
fi

 


cat $filename | egrep -v "DIRECTORY" |egrep $invertgrep $regexstring |  egrep $egrep1 |   sed -E "s|$pDir/|$pDir2|;s|$pDir/.*/|$pDir2|;s|(.*)/|$pDir2|" > $filename".rebase"

cat $filename".rebase" | egrep -v "/" | sed -E "s|^|$pDir2|" >> $filename".rebase"


if [[ $firstchar == "/" && $strsize == 1 && $strsize2 != 1 ]]
then

#echo "Modifying leftovers"
cat $filename".rebase" | egrep "/" > $filename".rebase2"

rm $filename".rebase"

mv $filename".rebase2" $filename."rebase"

fi
if [[ $regexstring != "*." ]]
then
    if [[ $pDir != "" && $pDir != ".*" && $pDir != "/"  ]]
    then
       cat $filename | egrep -v "$pDir"  > $tmpFilename
  
    else
        cat $filename |  egrep $invertgrep2 "$regexstring" > $tmpFilename
    
    fi

else
 
    if [[ $pDir != "" && $pDir != ".*" && $pDir != "/"  ]]
    then
 
    cat $filename | egrep -v "$pDir" > $tmpFilename
    else
    
    cat $filename |  > $tmpFilename
   
    fi

fi




cat "$filename.rebase" |  sed "s|/;|;|" > "$filename.rebase2"

cat "$filename.rebase2" > "$filename.rebase"



sort -u -t";" -k1,1 -o "$filename.rebase"{,}


opSize=$(cat "$filename.rebase" | wc -l)

echo "Total $opSize items moved"
cat "${filename}.rebase" >> $tmpFilename

sort -u -t";" -k1,1 -o $tmpFilename{,}

rm "$filename.rebase2"
rm "${filename}.rebase"
rm $filename
cp $tmpFilename $filename








}

delete_FileDir()
{

echo "Deleting filelist directory $1 from $filename"


#Handle case for non root folders checking the prefix /
firstchar=${1:0:1}

if [[ $firstchar == "/" ]]
then
    strsize=${#1} 
    pDir=${1:1:strsize}
    
    if [[ $strsize > 1 ]]
    then

       cat $filename | egrep -v "^$pDir" > $tmpFilename
      
    else

       echo "" > $tmpFilename


    fi
      

else


    cat $filename | egrep -v "$1" > $tmpFilename

fi


sort -u -t";" -k1,1 -o $tmpFilename{,}

sSize=$(cat $filename | wc -l)
eSize=$(cat $tmpFilename | wc -l)
((dSize=sSize-eSize))
echo "There were $dSize items deleted"


rm $filename
cp $tmpFilename $filename







}

delete_Files()
{

echo "Deleting files from $1 with regex $2"

if [[ $invertgrep == '' ]]
then
    invertgrep2="-v"
else
    invertgrep2=""


fi

#Handle case for non root folders checking the prefix /
firstchar=${1:0:1}

#echo "firstchar is $firstchar"
if [[ $firstchar == "/" ]]
then
    strsize=${#1} 
    pDir=${1:1:strsize}
    
    if [[ $strsize > 1 ]]
    then

       cat $filename | egrep $invertgrep2 "^$pDir/.*$regexstring;" > $tmpFilename
      
    else

       cat $filename | egrep $invertgrep2 "$regexstring;" > $tmpFilename
      
       


    fi
      

else


    cat $filename |  egrep $invertgrep2 "$1/.*$regexstring;" > $tmpFilename

fi


sort -u -t";" -k1,1 -o $tmpFilename{,}

sSize=$(cat $filename | wc -l)
eSize=$(cat $tmpFilename | wc -l)
((dSize=sSize-eSize))
echo "There were $dSize items deleted"


rm $filename
cp $tmpFilename $filename







}


rebase_Filelist()
{


echo "Rebasing filelist to $1"


#Handle case for non root folders checking the prefix /
firstchar=${1:0:1}
#echo "firstchar is $firstchar"
if [[ $firstchar == "/" ]]
then

    strsize=${#1} 
    pDir=${1:1:strsize}
    cat $filename | egrep $invertgrep $regexstring |  egrep "^$pDir/" | sed "s;^$pDir/;;" > $filename".rebase"



else

    cat $filename | egrep $invertgrep $regexstring |  egrep "$1/" | sed "s;.*$1/;;" > $filename".rebase"

fi


filename="${filename}.rebase"


#echo "filename after rebase is $filename"




}

#Params $key 
rebase_Directory()
{

        
        

            #echo "rebase is : $rebase"
            local KeySize=${#rebase} 
            #echo "keysize is : $KeySize"
            local keyPrefix=${rebase:1:KeySize}

        if [[ $KeySize > 0 ]]
        then
            combkey="$keyPrefix/$key"
        else
            combkey="$key"
        fi

            #echo "combkey is : $combkey"

        


}

generate_FileDirStruc()
{

echo "Printing Directory structure from listfile $filename"


truncate -s 0 $tmpFilename
   
#Edit to add root folder count
allcount=$(cat $filename | wc -l)
printf '%0.s\t    ' $(seq 1 1)



echo -e ". ($allcount)"



while IFS=" " read -r line; do


    res=$(echo $line | tr -cd '/' | wc -c)

    ((res++))
    printf '%0.s\t    ' $(seq 1 $res)

    filecount=$(cat $filename | grep "^$line/" | egrep $invertgrep $regexstring | wc -l)
    newline=$(echo $line | sed 's;.*/;;')
    echo "$line ($filecount)"

    

done < <(cat $filename | grep "DIRECTORY" | cut -d";" -f1 | sort)




}

#animated spinner function
spinner2()
{
  pid=$! # Process Id of the previous running command

  spin='-\|/'

  i=0
  while kill -0 $pid 2>/dev/null
  do
    i=$(( (i+1) %4 ))
    printf "\r${spin:$i:1}"
    sleep .2
   done

  printf "\r"
}

generate_Filelist()
{

    #Actions on file exists
   prompt_FileExist $filename

   if [[ $decision == "Y" ]]
   then
    touch $filename
    truncate -s 0 $filename
   fi



   #Do Rebase validation checking here before proceeding to loop directory
   rebaseKeySize=${#rebase} 
   #echo "RebaseKeySize : $rebaseKeySize"
   if (( $rebaseKeySize > 0 ))
   then
        rebaseFirstChar=${rebase:0:1}
        rebaseNextChars=${rebase:1:rebaseKeySize}


        if [[ $rebaseFirstChar != "/" ]]
        then
            echo "On DUMPDIR rebase directory must start with /"

            exit -1

           
        fi

         if (( $rebaseKeySize == 1 ))
            then
                echo "On DUMPDIR cannot use just / as rebase directory"

                exit -1

            fi

            
        if [[ $replacerebase = "true" && $decision == "A"  ]]
        then

            echo "replace file with $rebase"
            cat $filename | egrep -v "$rebaseNextChars" > "$filename.bak"
            rm $filename
            mv "$filename.bak" $filename



        fi
   fi

    

    ctrFile=0

    exec 3< <(find "$directory" -printf '%P\n' | sed -e 1d | egrep $invertgrep $regexstring | wc -l) 

    spinner2
    ctrSize=$(cat <&3)
    
    echo "Expected size is $ctrSize"

    

    while IFS=$" "  read -r md5 key; do
    #while IFS=$" "  read -r key; do
    
        test -z "$key" && continue

        rebase_Directory $key

        #combkey=$(rebase_Directory "$key")

        #echo "Combkey : $combkey"

        
        filelist02["$combkey"]="1"
       

        filelist02_md5["$combkey"]=$md5
        
        statres=$(stat -L -c "%a %U %G" "$directory/$key")
        tokens=( $statres )
        tmp_permissions=${tokens[0]}
        tmp_owner=${tokens[1]}
        tmp_group=${tokens[2]}
        
        
        
        filelist02_permissions["$combkey"]=$tmp_permissions
        filelist02_owner["$combkey"]=$tmp_owner
        filelist02_group["$combkey"]=$tmp_group

        ProgressBar ${ctrFile} ${ctrSize}


         ((ctrFile++)) 

    

    done < <(find "$directory" -type f   -exec md5sum {} +  | sed  "s;$directory/;;" | egrep $invertgrep $regexstring  )


    while IFS=$" "  read -r key; do
    
        test -z "$key" && continue

        rebase_Directory $key
        
        filelist02["$combkey"]="1"
       

        filelist02_md5["$combkey"]="DIRECTORY"

        
        statres=$(stat -L -c "%a %U %G" "$directory/$key")
        tokens=( $statres )
        tmp_permissions=${tokens[0]}
        tmp_owner=${tokens[1]}
        tmp_group=${tokens[2]}
        
        
        
        filelist02_permissions["$combkey"]=$tmp_permissions
        filelist02_owner["$combkey"]=$tmp_owner
        filelist02_group["$combkey"]=$tmp_group

        ProgressBar ${ctrFile} ${ctrSize}


         ((ctrFile++)) 



    done < <(find "$directory" -type d | sed -e 1d | sed  "s;$directory/;;" | egrep $invertgrep $regexstring  )

    echo " "

    for f in "${!filelist02[@]}" ; do
      test -z "$f" && continue
      echo "$f;${filelist02_md5["$f"]};${filelist02_permissions["$f"]};${filelist02_owner["$f"]};${filelist02_group["$f"]}" >> $filename
    done

    
    sort -u -t";" -k1,1 -o $filename{,}

    while IFS= read -r line
    do
        
        #echo "$line"
        logThis "${greenvid}$line${resetvid}" "INFO"

    done < "$filename"

    echo -e "\nTotal $ctrFile filelist items generated and saved to $filename ${resetvid}"


}

check_directory() {


    #Check for rebase
    #echo "rebase is $rebase"

    if [[ ! -z $rebase ]]
    then

        rebase_Filelist $rebase


    fi


    ctrSize=$(cat $filename | sort | grep -v '^\s*$\|^\s*\#'   | egrep $invertgrep "$regexstring" | wc -l)

    ctrLoop=0
    
    if [ $ctrSize == 0 ] 
    then

        echo "File Doesn't exist and or empty lists"
        exit -1

    fi

    echo -e "Reading list $filename, size : $ctrSize"

    

    while IFS=$";"  read -r key value permissions owner group; do
    
    #echo $key
        test -z "$key" && continue

        [ "${key:1:0}" == "#" ] && continue

        
        filelist01["$key"]="1"
        filelist01_md5["$key"]="$value"  
        test -z "$permissions" && permissions=$default_permissions

        filelist01_permissions["$key"]="$permissions"  
        
        test -z "$owner" && owner=$default_owner
        
        filelist01_owner["$key"]="$owner"  
        
        test -z "$group" && group=$default_group

        filelist01_group["$key"]="$group"  

        ProgressBar $ctrLoop $ctrSize

        ((ctrLoop++))

    done < <(cat $filename | sort | grep -v '^#'  | egrep $invertgrep "$regexstring" )


    ctrLoop=0
    echo -e "\nChecking directory $directory"

    ctrSize=$(find "$directory" -printf '%P\n' | sed -e 1d |  egrep $invertgrep "$regexstring" | wc -l)
   
    echo -e "Expected size is $ctrSize"
    #while IFS=$";"  read -r key; do

    #Comparing files
     while IFS=$" "  read -r md5 key; do
        
        #echo "in loop $md5 and $key"
        test -z "$key" && continue
        #echo $key
        tmpvalue=${filelist01["$key"]}

        if [[  -z $tmpvalue ]]
        then

            tmpvalue=0

            filelist01["$key"]=$tmpvalue
        else
            tmpvalue=$((tmpvalue+1)) 

            filelist01["$key"]=$tmpvalue

        fi     

        filelist02["$key"]="1"
    
        filelist02_md5["$key"]=$md5
        
        statres=$(stat -L -c "%a %U %G" "$directory/$key")
        tokens=( $statres )
        tmp_permissions=${tokens[0]}
        tmp_owner=${tokens[1]}
        tmp_group=${tokens[2]}
        
        filelist02_permissions["$key"]=$tmp_permissions
        filelist02_owner["$key"]=$tmp_owner
        filelist02_group["$key"]=$tmp_group
        
        


        ProgressBar $ctrLoop $ctrSize

        ((ctrLoop++))


    done < <(find "$directory" -type f   -exec md5sum {} +   | sed  "s;$directory/;;"  | egrep $invertgrep $regexstring)
    
    #Comparing subdirectories
     while IFS=$" "  read -r key; do
        
        #echo "in loop $md5 and $key"
        test -z "$key" && continue

        md5="DIRECTORY"
        #echo $key
        tmpvalue=${filelist01["$key"]}

        if [[  -z $tmpvalue ]]
        then

            tmpvalue=0

            filelist01["$key"]=$tmpvalue
        else
            tmpvalue=$((tmpvalue+1)) 

            filelist01["$key"]=$tmpvalue

        fi     

        filelist02["$key"]="1"
    
        filelist02_md5["$key"]=$md5
        
        statres=$(stat -L -c "%a %U %G" "$directory/$key")
        tokens=( $statres )
        tmp_permissions=${tokens[0]}
        tmp_owner=${tokens[1]}
        tmp_group=${tokens[2]}
        
        filelist02_permissions["$key"]=$tmp_permissions
        filelist02_owner["$key"]=$tmp_owner
        filelist02_group["$key"]=$tmp_group
        
        


        ProgressBar $ctrLoop $ctrSize

        ((ctrLoop++))


    done < <(find "$directory" -type d  | sed -e 1d |  sed  "s;$directory/;;"  | egrep $invertgrep $regexstring)
    

    echo " "


    for f in "${!filelist01[@]}" ; do
    
        test -z "$f" && continue
        
        echo "$f" 
    
    done | sort  > $tmpFilename



    ctrDiff=0
    ctrMatch=0


    while IFS= read -r key
    do

    tmpvalue=${filelist01["$key"]}

    if [  $tmpvalue -eq 0 ]
    then
        tmpvalue=0

    

        md5b=${filelist02_md5["$key"]}

    
        logThis "${redvid}File $key ($md5b) exist only in directory $2${resetvid}" "ERROR"
        
        ((ctrDiff++))


    elif [ $tmpvalue -eq 1 ]
        then

        md5a=${filelist01_md5["$key"]}
        logThis "${lightredvid}File $key ($md5a) exist only in the listfile $1${resetvid}" "ERROR"
        

        ((ctrDiff++))

    else
    
    md5a=${filelist01_md5["$key"]}
    md5b=${filelist02_md5["$key"]}

    permissions_a=${filelist01_permissions["$key"]}
    permissions_b=${filelist02_permissions["$key"]}

    owner_a=${filelist01_owner["$key"]}
    owner_b=${filelist02_owner["$key"]}

    group_a=${filelist01_group["$key"]}
    group_b=${filelist02_group["$key"]}

    if [  $md5a == $md5b ]
        then
    
            logThis "${greenvid}File $key match ($md5a) ${resetvid}" "INFO"


        

        check_FileAttributes


        ((ctrMatch++))
    
    else
    
            logThis "${lightredvid}Different File $key ($md5a) vs ($md5b) ${resetvid}" "ERROR"



            check_FileAttributes
            
            ((ctrDiff++))

    
    fi
    fi     

    done < $tmpFilename

    rm $tmpFilename

    if [[ ! -z $rebase ]]
    then

        rm $filename

    fi
 


}


while getopts 'ra:b:f:d:v:g:si' flag; do
  case "${flag}" in
    a) a_flag="${OPTARG}" ;;
    b) rebase="${OPTARG}" ;;
    f) filename="${OPTARG}" ;;
    d) directory="${OPTARG}" ;;
    g) regexstring="${OPTARG}" ;;
    s) silentmode='true' ;;
    i) invertgrep='-v' ;;
    r) replacerebase='true' ;;
    v) verbose="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done



script_logging_level=$verbose

#test segment

#create_DirIfNotExist $rebase $filename

#exit 1


#end testsegment


if [[ $a_flag != "MOVEDIR" && $a_flag != "DELETEDIR"  && $a_flag != "DELETEFILES" && $a_flag != "MOVEFILES" && $a_flag != "PRINTDIR" && $a_flag != "PRINTFILE" ]]
then
    check_DirExist $directory
else
    check_FileExist $filename
fi 

if [[  $a_flag == "DUMPDIR" ]]
then
    echo -e "Generating filelist from directory $directory ${resetvid}"

    generate_Filelist

exit
elif [[  $a_flag == "CHECKDIR" ]]
then

    check_directory
    echo "Summary   :   Total Conflicts found " $ctrDiff " , Total Match " $ctrMatch
    echo "              Message Count : INFO ${levels_ctr[INFO]} WARN ${levels_ctr[WARN]} ERROR ${levels_ctr[ERROR]} "

elif [[  $a_flag == "PRINTDIR" || $a_flag == "PRINTFILE" ]]
then

    generate_FileDirStruc

elif [[  $a_flag == "MOVEDIR" ]]
then

    move_FileDir $directory $rebase

elif [[  $a_flag == "DELETEDIR" ]]
then

    delete_FileDir $directory

elif [[  $a_flag == "DELETEFILES" ]]
then

    delete_Files $directory $regexstring

elif [[  $a_flag == "MOVEFILES" ]]
then

    move_Files $directory $rebase



else

    echo "Unknown action"
    print_usage
    
fi


#exec 2>&1





