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

# arg is path to file and file path

# This function use a list of video url to download  
# The file is used as follow:
# ${url}${delimiter}${id}${delimiter}${filepath}
#
download_video_from_list() {
  passfile="${HOME}/workspace/token/fu.txt"
  listpath="shared-folder/download-queue/youtube.txt"
  user="fu"
  url="192.168.0.199"
  delimiter=", "
  downloadDirectory="${HOME}/nc/yt-dl"
  help()
  {
	  echo "-l: file path to video list in nextcloud. Default is $listpath"
    echo "-s: Default directory to store file. Default is $downloadDirectory"
	  echo "-d: Delimiter used in video list. Default is $delimiter"
	  echo "-p: file path to password (optional. Default is $passfile)"
	  echo "-u: url (optional. Default is $url)"
	  echo "-n: username (optional. Default is $user)"
	  echo "-i: use --insecure arg in curl for ignoring ssl error"
  }

# flag with arg, use <c>:, put them first.
# flag without arg, use <c> after flag with args.
while getopts "l:p:u:n:ih" opt; do
  case $opt in
    l) listpath="$OPTARG";;

    d) delimiter="$OPTARG";;

    s) downloadDirectory="$OPTARG";;

    p) passfile="$OPTARG";;
	    
    u) url="$OPTARG";;

    n) user="$OPTARG";;

    i) insecure="true";;

    h) help
       exit;;

    ?)  echo "Invalid option -$OPTARG" >&2
        help
    	  exit;;
  esac
done
mkdir -p "$downloadDirectory"
if [ -z "$listpath" ]; then
	echo "Need -l arg."
	help
	exit
fi
listfile=$(ncp_get_file -t "$listpath" -p "$passfile" -u "$url" -n "$user" $($insecure && echo "-i"))
uncompletedListFile="$listfile"
while IFS= read -r line; do
  parse_list_line
  if [ -n "$lurl" ] ; then
  #sudo /usr/local/bin/youtube-dl -f 18 "${lurl}" --cookie 'cookie.txt' -o "/media/kingston/download/video/%(upload_date)s-[%(uploader)s]-%(title)s.%(ext)s"
  # could be needed to use full path of youtube-dl
  youtube-dl --restrict-filenames -f 18 "${lurl}" -o "${downloadDirectory}/${lid}-%(upload_date)s-%(uploader)s-%(title)s.%(ext)s" && echo "here" && ytcompleted="true"
  echo "yt completed $ytcompleted."
    if [ "$ytcompleted" = "true" ] ; then
      echo "moving ${lid} to ${lpath} in nextcloud"
      nc_upload_without_id
      echo "removing $line from list..."
      uncompletedListFile=$(echo "$listfile" | sed "/$lid/d") 
      localListFilePath="${downloadDirectory}/$(basename $listpath)"
      listfile="$uncompletedListFile"
      rm -f $localListFilePath
      echo "$uncompletedListFile" > "$localListFilePath" && 
      echo "Uploading list file: $localListFilePath to: $listpath .
      Content:
      $(cat $localListFilePath)
      End of content." &&
      ncp_upload_file -f "$localListFilePath" -t "${listpath}" -p "$passfile" -u "$url" -n "$user" $($insecure && echo "-i") &&  echo "Updated listfile" 

      

   fi
  
  fi

done <<< "$listfile"
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
    string="$line$delimiter"
    while [[ "$string"  ]]; do
      newarray+=( "${string%%"$delimiter"*}" )
      string=${string#*"$delimiter"}
    done
    lurl="${newarray[1]}"
    lid="${newarray[2]}"
    lpath="${newarray[3]}"

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
  fileName=$(ls "$downloadDirectory" | grep "${lid}")
  filePath="$downloadDirectory/$fileName"
  nameWithoutID=$(echo "${fileName#*${lid}-}")
  # Upload video to nextcloud
  ncp_upload_file -f "$filePath" -t "$lpath/$nameWithoutID" -p "$passfile" -u "$url" -n "$user" $($insecure && echo "-i") && rm "$filePath"

}


ncp_get_file() {
passfile="/home/jo/workspace/token/fu.txt"
user="fu"
url="192.168.2.52"
help()
{
	echo "-t: file path in nextcloud"
	echo "-p: file path to password (optional. Default is $passfile)"
	echo "-u: url (optional. Default is $url)"
	echo "-n: username (optional. Default is $user)"
	echo "-i: use --insecure arg in curl for ignoring ssl error"
}

# flag with arg, use <c>:, put them first.
# flag without arg, use <c> after flag with args.
while getopts "t:p:u:n:ih" opt; do
  case $opt in
    t) # to file path
	    ncppath="$OPTARG"
    	;;
    p) passfile="$OPTARG";;
	    
    u) url="$OPTARG";;

    n) user="$OPTARG";;

    i) insecure="true";;

    h) help
	exit;;

    ?) echo "Invalid option -$OPTARG" >&2
	help
    	exit;;
  esac
done

if [[ "$url" != http* ]] ; then 
	url="https://$url"
fi


pass=`cat $passfile`
if [ ! -z "$insecure" ]; then
	curl --insecure -X "GET" -u "$user:$pass" "$url/remote.php/dav/files/$user/$ncppath" 
else
	curl -X "GET" -u "$user:$pass" "$url/remote.php/dav/files/$user/$ncppath" 
fi
}

# Upload a file to ncp
# -t: file path in nextcloud
# -f: from file path to upload
# -p: password file path
# -u: url of nextcloud
# -n: username
# -i: ignore ssl error
ncp_upload_file() {
passfile="/home/jo/workspace/token/fu.txt"
user="fu"
url="192.168.2.52"
help()
{
	echo "-t: to - file path in nextcloud (optional, Starts at user folder)"
	echo "-f: from - file path to upload"
	echo "-p: file path to password (optional. Default is $passfile)"
	echo "-u: url (optional. Default is $url)"
	echo "-n: username (optional. Default is $user)"
	echo "-i: use --insecure arg in curl for ignoring ssl error"
}

# flag with arg, use <c>:, put them first.
# flag without arg, use <c> after flag with args.
while getopts "f:t:p:u:n:ih" opt; do
  case $opt in
    f) # from file path
	    filepath="$OPTARG"
    	;;
    t) # to file path
	    uploadpath="$OPTARG"
    	;;
    p) passfile="$OPTARG";;
	    
    u) url="$OPTARG";;

    n) user="$OPTARG";;

    i) insecure="true";;

    h) help
	exit;;

    ?) echo "Invalid option -$OPTARG" >&2
	help
    	exit;;
  esac
done

if [ -z "$filepath" ]; then
	echo "Need -f arg."
	help
	exit
fi
if [[ "$url" != http* ]]; then 
	url="https://$url"
fi

# Remove slash (/)
#if [ $url == */ ]; then 
#	url="$url"
#fi

echo "$url"
echo "from: $filepath"
echo "to: $uploadpath"
echo "curl command $url/remote.php/dav/files/$user/$uploadpath -T $filepath"
pass=`cat $passfile`
if [ ! -z "$insecure" ]; then
	echo "insecure option activated"
	curl --insecure -X "PUT" -u "$user:$pass" "$url/remote.php/dav/files/$user/$uploadpath" -T "$filepath"
else
	curl -X "PUT" -u "$user:$pass" "$url/remote.php/dav/files/$user/$uploadpath" -T "$filepath"
fi
echo "done."
}
