#!/bin/bash
#
# DMENU FILE EXPLORER
set -euo pipefail
_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo ".")")" && pwd)"
if [[  -f "${_path}/_dm-helper.sh" ]]; then
  # shellcheck disable=SC1090,SC1091
  source "${_path}/_dm-helper.sh"
else
  # shellcheck disable=SC1090
  echo "No helper-script found"
fi

source "$(get_config)"

#start="/home/jo/workspace/nextcloud/shared-folder"


check_updated_config

help()
{
	echo "###DMENU FILE EXPLORER###"
	echo
	echo "specify folder to start. fileexplorer \"/folder/to/start\"" 
	echo 
}

fileexplorer() {

start="${fileexplorer_start}/"
if [ ! -z "$1" ]; then
	start="$1"
fi
if [ ! -d "$start" ];
then
    echo "$start doesn't exists on your filesystem."
    help
    exit
fi

echo "$start"

currentpath="$start"
while true; do
	choice=$(ls -b -a "$currentpath" | ${DMENU} 'Select: ') #"$@")
	echo "$choice"
	case $choice in
		.) echo "Directory"
			break;;

		..) 
			currentpath="$(dirname "$currentpath")";;
		*) 
		currentpath="$currentpath/$choice"
		if [ ! -d "$currentpath" ]; then
			echo "File"
			break
		fi
		
	esac

done

echo "$currentpath"
}
