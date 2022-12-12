#!/bin/bash
#
# This scripts provides nextcloud related api funciton
#
# It works with oh-my-zsh shell (maybe just zsh), I do not know why.
#
# read with zsh: https://superuser.com/questions/555874/zsh-read-command-fails-within-bash-function-read1-p-no-coprocess
# Upload file to nextlcoud through api: https://linuxfun.org/en/2021/07/02/nextcloud-operation-api-with-curl-en/
#

#IFS= read -sr "?Enter a password: " password
#read "?Path to file: " filepath

config_init() {
nc_api_passfile="${HOME}/workspace/token/fu.txt"
nc_api_listpath="shared-folder/download-queue" #/wget.txt"
nc_api_user="fu"
nc_api_url="192.168.0.199"
nc_api_delimiter=", "

nc_api_downloadDirectory="${HOME}/nc"
mkdir -p "$nc_api_downloadDirectory"

nc_api_insecure="" # --insecure
nc_wget_list_file="wget.txt"
nc_yt_list_file="youtube.txt"
local_yt_log_file="${nc_api_downloadDirectory}/yt-log.txt"
local_wget_log_file="${nc_api_downloadDirectory}/wget-log.txt"
# function arg var
_get_file=""
_upload_file=""
_upload_file_nc_path=""
}
# This function use a list of file url to download a file and upload it
# to the entered path in nextcloud
# The file is used as follow:
# ${url}${delimiter}${id}${delimiter}${filepath}
#
download_file_from_list_with_wget() {

# flag with arg, use <c>:, put them first.
# flag without arg, use <c> after flag with args.
mkdir -p "$nc_api_downloadDirectory"
if [ -z "$nc_api_listpath" ]; then
	echo "nc_api_listpath is empty"
	exit
fi
_get_file="$nc_api_listpath/$nc_wget_list_file"
listfile=$(ncp_get_file) 
uncompletedListFile="$listfile"
  if [ -n "$listfile" ] ; then
    while IFS= read -r line; do
    parse_list_line
    if [ -n "$lurl" ] ; then
      completed="false"
      filename=$(basename "$lurl")
      wget -c "$lurl" -O "${nc_api_downloadDirectory}/${lid}-$filename" > "$local_wget_log_file" && completed="true" 
      echo "Completed $completed."
        if [ "$completed" = "true" ] ; then
          echo "moving ${lid} to ${lpath} in nextcloud"
          nc_upload_without_id
          echo "removing $line from list..."
          uncompletedListFile=$(echo "$listfile" | sed "/$lid/d") 
          localListFilePath="${nc_api_downloadDirectory}/${nc_wget_list_file}"
          listfile="$uncompletedListFile"
          rm -f $localListFilePath
          echo "$uncompletedListFile" > "$localListFilePath" && 
          echo "Uploading list file: $localListFilePath to: $listpath .
          Content:
          $(cat $localListFilePath)
          End of content." &&
          _upload_file="$localListFilePath" &&
          _upload_file_nc_path="$nc_api_listpath/$nc_wget_list_file" &&
          ncp_upload_file &&  echo "Updated listfile" 

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

mkdir -p "$nc_api_downloadDirectory"
if [ -z "$nc_api_listpath" ]; then
	echo "Need listpath arg."
	help
	exit
fi
_get_file="$nc_api_listpath/$nc_yt_list_file"
listfile=$(ncp_get_file) 
uncompletedListFile="$listfile"
  if [ -n "$listfile" ] ; then
    while IFS= read -r line; do
    parse_list_line
    if [ -n "$lurl" ] ; then
      #sudo /usr/local/bin/youtube-dl -f 18 "${lurl}" --cookie 'cookie.txt' -o "/media/kingston/download/video/%(upload_date)s-[%(uploader)s]-%(title)s.%(ext)s"
      # could be needed to use full path of youtube-dl
      youtube-dl --restrict-filenames -f 18 "${lurl}" -o "${nc_api_downloadDirectory}/${lid}-%(upload_date)s-%(uploader)s-%(title)s.%(ext)s" && ytcompleted="true"
      echo "yt completed $ytcompleted."
        if [ "$ytcompleted" = "true" ] ; then
          echo "moving ${lid} to ${lpath} in nextcloud"
          nc_upload_without_id
          echo "removing $line from list..."
          uncompletedListFile=$(echo "$listfile" | sed "/$lid/d") 
          localListFilePath="${nc_api_downloadDirectory}/$nc_yt_list_file"
          rm -f $localListFilePath
          echo "$uncompletedListFile" > "$localListFilePath" && 
          echo "Uploading list file: $localListFilePath to: $listpath .
          Content:
          $(cat $localListFilePath)
          End of content." &&
          _upload_file="$localListFilePath" &&
          _upload_file_nc_path="$nc_api_listpath/$nc_yt_list_file" &&
          ncp_upload_file &&  echo "Updated listfile" 

        fi
      fi
    done <<< "$listfile"
  fi
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
    string="$line$nc_api_delimiter"
    while [[ "$string"  ]]; do
      newarray+=( "${string%%"$nc_api_delimiter"*}" )
      string=${string#*"$nc_api_delimiter"}
    done
    lurl="${newarray[0]}"
    lid="${newarray[1]}"
    lpath="${newarray[2]}"

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
  fileName=$(ls "$nc_api_downloadDirectory" | grep "${lid}")
  filePath="$nc_api_downloadDirectory/$fileName"
  nameWithoutID=$(echo "${fileName#*${lid}-}")
  # Upload video to nextcloud
  _upload_file="$filePath"
  _upload_file_nc_path="$lpath/$nameWithoutID"
  ncp_upload_file && rm "$filePath"

}


ncp_get_file() {

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
ncp_upload_file() {
if [ -z "$_upload_file" ]; then
	echo "Need _upload_file arg."
	exit
fi
if [[ "$nc_api_url" != http* ]]; then 
	nc_api_url="https://$nc_api_url"
fi

# Remove sla-sh (/)
#if [ $url == */ ]; then 
#	url="$url"
#fi

echo "$nc_api_url"
echo "from: $_upload_file"
echo "to: $_upload_file_nc_path"
echo "curl command $nc_api_url/remote.php/dav/files/$nc_api_user/$_upload_file_nc_path -T $_upload_file"
pass=`cat $nc_api_passfile`
	curl "$nc_api_insecure" -X "PUT" -u "$nc_api_user:$pass" "$nc_api_url/remote.php/dav/files/$nc_api_user/$_upload_file_nc_path" -T "$_upload_file"
echo "done."
}

config_init
