#!/bin/bash
# set shell options
set -e # abort on first error
shopt -s nullglob # allow filename patterns which match no files to expand to a null string, rather than themselves
shopt -s dotglob
# define queue
queue=()
function queueecho {
    for item in "${queue[@]}"; do
        echo "$item"
    done
}
function queueexec {
    queueecho | parallel "-j$parallelcount" --eta "eval {}"
}
function iteratedirs {
    local dir="$1"
    local depth="$2"
    local current_rel_dir="$3"

    for item in "$dir"/*; do
        if [[ -d $item ]]; then
            if [[ $depth == none ]] || [[ $currentlevel -lt $depth ]]; then
                iteratedirs "${item}" $(($depth + 1)) "${current_rel_dir}${item##*/}/"
            fi
        elif [[ -f $item ]]; then
            if [[ ! $filter ]] || [[ $item =~ $filter ]]; then
                name=${item##*/}
                namewithoutextension=${name%.*}
                queue+=("ITERATOR_FULL_PATH=\"$item\" ITERATOR_FILE_NAME=\"$name\" ITERATOR_FILE_NAME_WITHOUT_EXTENSION=\"$namewithoutextension\" ITERATOR_CURRENT_DIR=\"$dir\" ITERATOR_CURRENT_REL_DIR=\"$current_rel_dir\" ITERATOR_BASE_DIR=\"$basedir\" ITERATOR_TARGET_DIR=\"$targetdir/$current_rel_dir\" \"$cmd\" $append")
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
read= argcount=0 append= basedir=. targetdir= depth=none cmd= filter= parallelcount=+0 noconfirm=
for arg in "$@"
do
    if [[ $arg == --base-dir ]]; then
        read=basedir
    elif [[ $arg == --depth ]]; then
        read=depth
    elif [[ $arg == --cmd ]]; then
        read=cmd
    elif [[ $arg == --filter ]]; then
        read=filter
    elif [[ $arg == --args ]]; then
        read=arguments
    elif [[ $arg == --parallel-count ]]; then
        read=parallelcount
    elif [[ $arg == --target-dir ]]; then
        read=target
    elif [[ $arg == --no-confirm ]]; then
        noconfirm=true
    elif [[ $arg == --help ]] || [[ $arg == -h ]]; then
        echo "${bold}Runs a script for each file in a directory hierarchy using GNU parallel.${normal}
--base-dir                            base directory (current directory by default)
--target-dir                          target directory (base directory by default)
--depth                               maximal recursion depth (unlimited by default)
--cmd                                 command to be executed
--filter                              regular expression to filter files, eg. ${bold}.*\.((mp4$)|(mp3$))${normal}
--args                                arguments to be passed to cmd
--no-confirm                          generated commands will be executed without prompt for confirmation
--parallel-count                      maximal number of commands to be executed parallel

${bold}The following environment variables will be set when running the script:${normal}
ITERATOR_FULL_PATH                    current file path
ITERATOR_FILE_NAME                    current file name with extension
ITERATOR_FILE_NAME_WITHOUT_EXTENSION  current file name without extension
ITERATOR_CURRENT_DIR                  current directory
ITERATOR_BASE_DIR                     base directory (specified using --base-dir)
ITERATOR_CURRENT_REL_DIR              current directory (relative to the base directory)
ITERATOR_TARGET_DIR                   target directory for the current file
"
        exit 0
    else
        if [[ $read == arguments ]]; then
            append="$append \"$arg\""
        elif [[ $read == basedir ]]; then
            basedir=$arg
        elif [[ $read == depth ]]; then
            if ! [[ $arg =~ ^[0-9]+$ ]]; then
               echo "${bold}${red}Error:${normal} ${bold}specified depth »$arg« is not an unsigned number.${normal}"
               exit 1
            fi
            depth=$arg
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
[[ $targetdir ]] || targetdir=$basedir
if [[ ! $cmd ]]; then
    echo "${bold}${red}Error:${normal} ${bold}No command specified.${normal}"
    exit 1
fi
# start recursive iteration and exec queue
iteratedirs "$basedir" 0
if [[ ${#queue[@]} -ge 1 ]]; then
    echo "${bold}Generated queue${normal}"
    queueecho
    if [[ $noconfirm ]]; then
        queueexec
    else
        while true; do
            read -p "${bold}Do you want to execute ${#queue[@]} commands [y/n]?${normal} " yn
            case $yn in
                [Yy]*) queueexec; break;;
                [Nn]*) exit;;
                *) echo "${bold}Please answer yes or no.${normal}";;
            esac
        done
    fi
else
    echo "${bold}${yellow}Warning:${normal} ${bold}Queue is empty.${normal}"
fi
