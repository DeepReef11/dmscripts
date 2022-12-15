#!/bin/bash
#
# This scripts provides nextcloud related api funciton
#
#
# -> youtube-dl must be installed properly for crontab root (sudo crontab -e)
#sudo apt remove youtube-dl
#sudo apt install python3-pip
#python3 -m pip install youtube-dl
#
# -> jq must be installed
# sudo apt install jq
#

#IFS= read -sr "?Enter a password: " password
#read "?Path to file: " filepath

config_init() {
nc_api_passfile="${HOME}/workspace/token/fu.txt"
nc_api_listpath="shared-folder/download-queue" #/wget.txt"
nc_api_user="fu"
nc_api_url="192.168.0.199"
nc_api_list_delimiter=", "
nc_api_insecure="" # --insecure
nc_api_yt_list_file="$nc_api_listpath/youtube.txt"
nc_api_wget_list_file="$nc_api_listpath/wget.txt"
nc_api_completed_list_file="$nc_api_listpath/completed.txt"

local_download_directory="${HOME}/nc"
mkdir -p "$local_download_directory"
local_yt_list_file="$local_download_directory/youtube.txt"
local_wget_list_file="$local_download_directory/wget.txt"
local_completed_list_file="$local_download_directory/completed.txt"
touch "$local_yt_list_file" "$local_wget_list_file" "$local_yt_log_file" "$local_wget_log_file"
rm -f "$local_completed_list_file"
nc_get_file "$nc_api_completed_list_file" > "$local_completed_list_file" || touch "$local_completed_list_file"

local_yt_log_file="${local_download_directory}/yt-log.txt"
local_wget_log_file="${local_download_directory}/wget-log.txt"
}

# This function use a list of file url to download a file and upload it
# to the entered path in nextcloud
# The file is used as follow:
# ${url}${delimiter}${id}${delimiter}${filepath}
download_file_from_list_with_wget() {
  if [ -z "$nc_api_listpath" ]; then
	  echo "nc_api_listpath is empty"
	  exit
  fi
  local listfile
  listfile=$(nc_get_file "$nc_api_wget_list_file") 
    if [ -n "$listfile" ] ; then
      while IFS= read -r line; do
      parse_list_line
      if [ -n "$lurl" ] ; then
        local completed="false"
        local filename
        filename=$(basename "$lurl")
        wget -c "$lurl" -O "${local_download_directory}/$filename" > "$local_wget_log_file" && completed="true" 
        echo "Completed $completed."
        if [ "$completed" = "true" ] ; then
          nc_upload_file -f "$local_download_directory/$filename" -t "$lpath/$filename" &&
          completed_list_line "$nc_api_wget_list_file" "$local_wget_list_file" "$lurl" &&
          rm -f "$local_download_directory/$filename"
        fi
      fi
    done <<< "$listfile"
  fi
}




# This function use a list of video url to download  
# The file is used as follow:
# ${url}${delimiter}${id}${delimiter}${filepath}
#
download_video_from_list() {

if [ -z "$nc_api_listpath" ]; then
	echo "Need listpath arg."
	exit
fi
local listfile
listfile=$(nc_get_file "$nc_api_yt_list_file") 
  if [ -n "$listfile" ] ; then
    while IFS= read -r line; do
    parse_list_line
    if [ -n "$lurl" ] ; then
      #sudo /usr/local/bin/youtube-dl -f 18 "${lurl}" --cookie 'cookie.txt' -o "/media/kingston/download/video/%(upload_date)s-[%(uploader)s]-%(title)s.%(ext)s"
      # could be needed to use full path of youtube-dl
      local completed="false"
      sudo /usr/local/bin/youtube-dl "${lurl}" --restrict-filenames -c -f 18 -o "${local_download_directory}/%(upload_date)s-%(uploader)s-%(title)s.%(ext)s" >> "$local_yt_log_file" && completed="true" 
      echo "yt completed $completed."
        if [ "$completed" = "true" ] ; then
          local file_name
          file_name=$(/usr/local/bin/youtube-dl "${lurl}" --restrict-filenames -j | jq '._filename')
          local file_path="$local_download_directory/$file_name"
          # upload video to nc
          nc_upload_file -f "$file_path" -t "$lpath/$file_name" && 
            completed_list_line "$nc_api_yt_list_file" "$local_yt_list_file" "$lurl" &&
          rm -f "$file_path"
        fi
      fi
    done <<< "$listfile"
  fi
}

# Download list file, remove line then upload list file back. It should prevent removing newly added line while downloading files.
# param:
# $1: nc path to list file
# $2: local path to list file
# $3: string to remove. Usually the url of the file.
completed_list_line() {
  local nc_list_path="$1"
  local local_list_path="$2"
  local to_remove="$3"
  if [ -z "$nc_list_path" ] || [ -z "$to_remove" ]; then
    echo "Arguments not provided."
    exit
  fi
  local list_file
  list_file=$(nc_get_file "$nc_list_path") 
  local uncompleted_list_file
  uncompleted_list_file=$(echo "$list_file" | sed "\|$to_remove|d") 
  rm -f "$local_list_path"
  echo "$uncompleted_list_file" > "$local_list_path" &&
  nc_upload_file -f "$local_list_path" -t "$nc_list_path" && echo "Updated $nc_list_path"
  echo "$list_file" | grep "$to_remove" >> "$local_completed_list_file" &&
  nc_upload_file -f "$local_completed_list_file" -t "$nc_api_completed_list_file" && echo "Updated $nc_api_completed_list_file"

}

# Take a list file line and parse it.
# Param:
# $line: line of list file
# Output:
# $lid: ID of file
# $lurl: url of file
# $lpath: path to nextcloud
#
parse_list_line() {
  lurl=""
  lpath=""
  lid=""
  trimmed=$(echo "$line" | xargs)
  if [ -n "$trimmed" ] && [[ "$trimmed" != "#"*  ]] ; then
    newarray=()
    string="$line$nc_api_list_delimiter"
    while [[ "$string"  ]]; do
      newarray+=( "${string%%"$nc_api_list_delimiter"*}" )
      string=${string#*"$nc_api_list_delimiter"}
    done
    lurl="${newarray[0]}"
    lpath="${newarray[1]}"
    lid="${newarray[2]}"

  fi
}

# Upload file without ID.
# Param:
# $downloadDirectory: local directory to download files 
# $lpath: path to upload file in nextcloud
# $passfile: path to password
# $url: Url to nextcloud
# $user: Nextcloud user
# $insecure: Must be declared to make insecure upload (insecure="true")
nc_upload_without_id() {
  local fileName=$(ls "$local_download_directory" | grep "${lid}")
  local filePath="$local_download_directory/$fileName"
  local nameWithoutID=$(echo "${fileName#*${lid}-}")
  # Upload video to nextcloud

  nc_upload_file -f "$filepath" -t "$lpath/$nameWithoutID" && rm "$filePath"
}


nc_get_file() {
local _get_file="$1"
if [[ "$nc_api_url" != http* ]] ; then 
	nc_api_url="https://$nc_api_url"
fi


pass=`cat $nc_api_passfile`
	curl "$nc_api_insecure" -X "GET" -u "$nc_api_user:$pass" "$nc_api_url/remote.php/dav/files/$nc_api_user/$_get_file" 
}

# Upload a file to ncp
# -t: file path in nextcloud
# -f: from file path to upload
# -p: password file path
# -u: url of nextcloud
# -n: username
# -i: ignore ssl error
nc_upload_file() {

  local OPTIND
 local insecure="$nc_api_insecure"
 local to_nc_path=""
 local upload_file=""
  while getopts "f:t:i" opt; do
    case $opt in
      f) # from file path
              upload_file="$OPTARG"
          ;;
      t) # to file path
              to_nc_path="$OPTARG"
          ;;
  i) insecure="-i";;
    *) echo "Upload file: Invalid argument"
      exit;;
  esac
  done

if [ -z "$upload_file" ]; then
	echo "Need -f arg."
	exit
fi
if [[ "$nc_api_url" != http* ]]; then 
	nc_api_url="https://$nc_api_url"
fi
if [[ "$to_nc_path" == "/"* ]]; then
        to_nc_path=$(echo "$to_nc_path" | cut -c 2-)
fi

# Remove sla-sh (/)
#if [ $url == */ ]; then 
#	url="$url"
#fi

echo "$nc_api_url"
echo "from: $upload_file"
echo "to: $to_nc_path"
echo "curl command $nc_api_url/remote.php/dav/files/$nc_api_user/$to_nc_path -T $upload_file"
pass=`cat $nc_api_passfile`
	curl "$insecure" -X "PUT" -u "$nc_api_user:$pass" "$nc_api_url/remote.php/dav/files/$nc_api_user/$to_nc_path" -T "$upload_file"
echo "done."
}

config_init
