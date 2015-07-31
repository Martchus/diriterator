#!/bin/sh
# define queue
queue=()
function queueecho {
    for item in "${queue[@]}"
    do
        echo $item
    done
}
function queueexec {
    queueecho | parallel "-j$parallelcount" --eta "eval {}"
}
function iteratedirs {
    shopt -s nullglob # from doc: If set, Bash allows filename patterns which match no files to expand to a null string, rather than themselves. 
    for item in "$1/"*
    do
        if [ -d "$item" ]; then
            if [[ $dept == none ]] || [ $currentlevel -lt $dept ]; then
                iteratedirs "${item}" $(($2 + 1)) "${3}${item##*/}/"
            fi
        elif [ -f "$item" ]; then
            if [[ $filter == "" ]] || [[ "$item" =~ $filter ]]; then
                name=${item##*/}
                namewithoutextension=${name%.*}
                queue+=("ITERATOR_FULL_PATH=\"$item\" ITERATOR_FILE_NAME=\"$name\" ITERATOR_FILE_NAME_WITHOUT_EXTENSION=\"$namewithoutextension\" ITERATOR_CURRENT_DIR=\"$1\" ITERATOR_CURRENT_REL_DIR=\"$3\" ITERATOR_BASE_DIR=\"$basedir\" ITERATOR_TARGET_DIR=\"$targetdir/$3\" \"$cmd\" $append")
            else
                echo "${bold}${blue}Info:${normal} ${bold}Skipping »$item«.${normal}"
            fi
        else
            echo "${bold}${yellow}Warning:${normal} ${bold}Item »$item« is neither a directory nor a file and will be skipped.${normal}"
        fi
    done
}
# determine sequences for formatted output
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
bold=$(tput bold)
normal=$(tput sgr0)
# parse arguments
read=
# read arguments
argcount=0
append=
basedir=./
dept=none
cmd=
filter=
targetdir=
parallelcount=+0
noconfirm=false
for arg in "$@"
do
    if [[ "--base-dir" == $arg ]]; then
        read=basedir
    elif [[ "--dept" == $arg ]]; then
        read=dept
    elif [[ "--cmd" == $arg ]]; then
        read=cmd
    elif [[ "--filter" == $arg ]]; then
        read=filter
    elif [[ "--args" == $arg ]]; then
        read=arguments
    elif [[ "--parallel-count" == $arg ]]; then
        read=parallelcount
    elif [[ "--target-dir" == $arg ]]; then
        read=target
    elif [[ "--no-confirm" == $arg ]]; then
        noconfirm=true
    elif [[ "--help" == $arg ]]; then
        echo "${bold}Runs a script for each file in a directory hierarchy using GNU parallel.${normal}
--base-dir       the base directory (./ by default)
--target-dir     the target directory (base directory by default)
--dept           the maximal recursion dept (unlimited by default)
--cmd            the command to be executed
--filter         a regular expression to filter files, eg. ${bold}.*\.(mp4$)${normal}
--args           the arguments to be passed to cmd
--no-confirm     generated commands will be executed without prompt for confirmation
--parallel-count the maximal number of commands to be executed parallel

${bold}The following environment variables will be set when running the script:${normal}
ITERATOR_FULL_PATH                    Path of the current file.
ITERATOR_FILE_NAME                    Full name of the current file.
ITERATOR_FILE_NAME_WITHOUT_EXTENSION  Name of the current file without extension.
ITERATOR_CURRENT_DIR                  Path of the current directory.
ITERATOR_BASE_DIR                     Path of the base directory (specified using --base-dir).
ITERATOR_CURRENT_REL_DIR              Path of the current directory (relative to the base directory).
ITERATOR_TARGET_DIR                   Path of the target directory for the current file (specified --target-dir + ITERATOR_CURRENT_REL_DIR).
"
        exit 0
    else
        if [[ $read == arguments ]]; then
            append="$append \"$arg\""
        elif [[ $read == basedir ]]; then
            basedir=$arg
        elif [[ $read == dept ]]; then
            if ! [[ $arg =~ ^-?[0-9]+$ ]]; then
               echo "${bold}${red}Error:${normal} ${bold}specified dept »$arg« is not a number.${normal}"
               exit 1
            fi
            dept=$arg
        elif [[ $read == cmd ]]; then
            cmd=$arg
        elif [[ $read == filter ]]; then
            filter=$arg
        elif [[ $read == parallelcount ]]; then
            parallelcount=$arg
        elif [[ $read == target ]]; then
            targetdir=$arg
        else
            echo "${bold}${red}Error:${normal} ${bold}Invalid argument »$arg« specified.${normal}"
            exit 1
        fi
        if [[ $read != arguments ]]; then
            read=
        fi
    fi
done
# validate specified arguments, use base directory as target directory if not specified
if [[ $targetdir == "" ]]; then
    targetdir=$basedir
fi
if [[ $cmd == "" ]]; then
    echo "${bold}${red}Error:${normal} ${bold}No command specified.${normal}"
    exit 1
fi
# start recursive iteration and exec queue
iteratedirs "$basedir" 0
if [[ ${#queue[@]} -ge 1 ]]; then
    echo "${bold}Generated queue${normal}"
    queueecho
    if [[ $noconfirm == true ]]; then
        queueexec
    else
        while true; do
            read -p "${bold}Do you want to execute the commands [y/n]?${normal} " yn
            case $yn in
                [Yy]* ) queueexec; break;;
                [Nn]* ) exit;;
                * ) echo "${bold}Please answer yes or no.${normal}";;
            esac
        done
    fi
else
    echo "${bold}${yellow}Warning:${normal} ${bold}Queue is empty.${normal}"
fi
