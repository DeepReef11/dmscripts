#!/usr/bin/env bash

# Script name: _dm-helper
# Description: A helper script for the other scripts in the collection.
# Dependencies:
# GitLab: https://www.gitlab.com/dwt1/dmscripts
# License: https://www.gitlab.com/dwt1/dmscripts/LICENSE
# Contributors: Simon Ingelsson
#               HostGrady
#               aryak1

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a helper-script it does not do anything on its own."
    exit 1
fi

###########################
#   Configuration stuff   #
###########################

get_local_config() {
  # Do some subshell magic finding out where the script we are running 
  # is located and checking if ../config is a dir relative to the script
  echo "$(
    cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo ".")")./"
    if [[ -d "${PWD}/config" ]]; then
      echo "${PWD}/config"
    fi
  )"
}

get_config() {
  local _config_files=()
  local _local_conf
  _local_conf="$(get_local_config)"

  # add User config path
  _config_files+=( "${HOME}/.config/dmscripts/config" )

  # Add git-repo relative config path (if exits)
  [[ -f "${_local_conf}/config" ]] && _config_files+=( "${_local_conf}/config" )

  # Add global installed config path
  _config_files+=( "/etc/dmscripts/config" )

  for conf in "${_config_files[@]}"; do
    if [[ -f ${conf} ]]; then
      echo "${conf}"
      return
    fi
  done
}

get_tips() {
	echo "$(dirname $(get_config))/tips"
}

md_file_to_viewer() {
	viewerpipingflag=""
	if [ "$PDF_VIEWER" == "zathura" ] ; then
		echo "is zathura"
		viewerpipingflag="-"
		pandoc -t pdf "$filepath" | $PDF_VIEWER $viewerpipingflag
	else
		$PDF_VIEWER "$filepath"
	fi

}

#
create_directory() {
  # $1: Path of directory
  # $2: Optional string for the prompt
  # Output: $dirpath
  # 
  # Other output:
  # $(create_directory | tail -n1) 
  txtPrompt="Name of directory: "
  if [ "$#" -gt 1 ] ; then
      txtPrompt="$2"
  fi 

	filepath="$1"  # TODO: a start path for archives could be added in config. 
  dirname=""
  while [ "$dirname" == "" ] ; do 
	  	dirname=$(dmenu -p "$txtPrompt" < /dev/null)
  done
  dirpath="$filepath/$dirname" 
	mkdir "$dirpath"
  echo "$dirpath"
  
}

file_explorer() {

start="${fileexplorer_start}"
if [ "$#" -gt 0 ] && [ ! -z "$1" ] ; then
	start="$1"
fi
if [ ! -d "$start" ];
then
    echo "$start doesn't exists on your filesystem."
    help
    exit 1
fi

txtMkDir="Create a new directory"
currentpath="$start"
br="\n"
while true; do
  choice=$(echo -e "$txtMkDir\n$(ls -b -a "$currentpath")" | ${DMENU} 'Select: ') #"$@")
	case $choice in
    "$txtMkDir") 
      currentpath=$(create_directory $currentpath $txtMkDir)
      ;; 
		.) 
			break;;
		..) 
			currentpath="$(dirname "$currentpath")";;
		*) 
		  currentpath="$currentpath/$choice"
		  if [ ! -d "$currentpath" ]; then
			break
		fi
		
	esac

done

echo "$currentpath"
}

# Check if config has updates that should be displayed to the user
check_updated_config() {
  local _base_file
  local _config_file
  _base_file=-1
  [[ -f /etc/dmscripts/config ]] && _base_file="/etc/dmscripts/config"
  _local_conf="$(get_local_config)"
  [[ -f "${_local_conf}/config" ]] && _base_file=${_local_conf}/config
  _config_file=$(get_config)

  [[ "${_config_file}" == "${_base_file}" ]] && return

  _config_file_revision=$(grep "^_revision=" "${_config_file}")
  _base_file_revision=$(grep "^_revision=" "${_base_file}")

  if [[ ! "${_config_file_revision}" == "${_base_file_revision}" ]] ; then
    diff -y "${_config_file}" "${_base_file}" | less
    echo  "${_config_file}  > ${_base_file}"
    echo  "New revision of the configuration detected, please review and set ${_base_file_revision} in ${_config_file} when done"
  fi
}

######################
#   Error handling   #
######################

# Simple warn function
warn () {
  printf 'Warn: %s\n' "$1"
}

# Simple error function
err () { 
  printf 'Error: %s\n' "$1"
  exit 1
}

############################
#   Dislay server checks   #
############################

# Boiler code for if you want to do something with display servers

#function() {
#  case "$XDG_SESSION_TYPE" in
#    'x11') something with x;;
#    'wayland') something with wayland;;
#    *) err "Unknown display server";;
#  esac
#}

# Function to copy to clipboard with different tools depending on the display server

cp2cb() {
  case "$XDG_SESSION_TYPE" in
    'x11') xclip -r -selection clipboard;;
    'wayland') wl-copy -n;; 
    *) err "Unknown display server";; 
  esac
}

grep-desktop() {
  case "$XDG_SESSION_TYPE" in
    'x11') grep "Name=" /usr/share/xsessions/*.desktop | cut -d'=' -f2;;
    'wayland') grep "Name=" /usr/share/wayland-sessions/*.desktop | cut -d'=' -f2 || grep "Name=" /usr/share/xsessions/*.desktop | grep -i "wayland" | cut -d'=' -f2 | cut -d' ' -f1;; 
    *) err "Unknown display server";;
  esac
}

###############
#   Parsing   #
###############

xmlgetnext () {
  local IFS='>'
  # we need to mangle backslashes for this to work
  # shellcheck disable=SC2162
  read -d '<' TAG VALUE
}

parse_rss() {
  echo "$1" | while xmlgetnext ; do
    case $TAG in
        'entry')
          title=''
          link=''
          published=''
          ;;
        'media:title')
          title="$VALUE"
          ;;
        'yt:videoId')
          link="$VALUE"
          ;;
        'published')
          published="$(date --date="${VALUE}" "+%Y-%m-%d %H:%M")"
            ;;
        '/entry')
          echo " ${published} | ${link} | ${title}"
          ;;
        esac
  done
}
