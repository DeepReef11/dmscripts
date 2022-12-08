#!/usr/bin/env bash

set -euo pipefail
_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo ".")")" && pwd)"
if [[  -f "${_path}/_dm-helper.sh" ]]; then
  # shellcheck disable=SC1090,SC1091
  source "${_path}/_dm-helper.sh"
else
  # shellcheck disable=SC1090
  echo "No helper-script found"
fi
if [[ -f "${_path}/dm-file-explorer.sh" ]]; then
	source "${_path}/dm-file-explorer.sh"
else
	echo "No file explorer script found"
fi

source "$(get_config)" # from _dm-helper.sh
# $(get_tips) # from _dm-helper.sh

check_updated_config

add_new_tip() {
	filepath=$(file_explorer "${findtips_start}")
	echo "$filepath"
	keyname=""
	while [ "$keyname" == "" ] ; do 
		keyname=$(dmenu -p "Name for this tip file: " < /dev/null)
	done	
	echo -e "findtips[\"$keyname\"]=\"$filepath\"" >> $(get_tips)

}

function main() {
	echo "$(get_config)"
	echo "$(get_tips)"
	if [ ! -f "$(get_tips)" ] || ! $(grep -q "findtips" "$(get_tips)") ; then
		echo -e "# path${confedit_delimiter}name\ndeclare -A findtips" >> $(get_tips)

	fi
	#tips=$(cat "$(get_tips)")
	source "$(get_tips)"
	#echo "${!findtips[@]}"
	NewLine=$'\n'
	txtAddChoice="Add tip file to list"
	txtEditTipsFile="Edit tips file"
	choice=$(printf '%s\n' "$txtAddChoice${NewLine}${txtEditTipsFile}${NewLine}${!findtips[@]}" | sort | ${DMENU} 'Select tip file: ' "$@") 	
	
  filepath=""
	if [ "$choice" == "$txtAddChoice" ]; then
		add_new_tip
	elif [ "$choice" == "$txtEditTipsFile" ] ; then
		$DMEDITOR "$(get_tips)"	
    exit 0
	else
		echo "$choice"
		filepath="${findtips["${choice}"]}"
	fi
	if [ ! -f "$filepath" ] ; then
    exit 1
  elif [[ "$filepath" == *.md ]]; then
		md_file_to_viewer
	else
		$PDF_VIEWER "$filepath"
	fi
}
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
