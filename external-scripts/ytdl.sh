#!/bin/bash
# This script use a list of video url to download  
# The file is used as follow:
# ${url}${delimiter}${id}${delimiter}${filepath}
#

source "ncp-api" 

download_video_from_list() {
  passfile="/home/jo/workspace/token/fu.txt"
  listpath="shared-folder/download-queue/ytncp.txt"
user="fu"
url="192.168.2.52"
help()
{
	echo "-l: file path to video list in nextcloud. Default is $listpath"
	echo "-p: file path to password (optional. Default is $passfile)"
	echo "-u: url (optional. Default is $url)"
	echo "-n: username (optional. Default is $user)"
	echo "-i: use --insecure arg in curl for ignoring ssl error"
}

# flag with arg, use <c>:, put them first.
# flag without arg, use <c> after flag with args.
while getopts "l:p:u:n:ih" opt; do
  case $opt in
    l) # from file path
	    filepath="$OPTARG"
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
	echo "Need -l arg."
	help
	exit
fi
if [ $url != http* ]; then 
	url="https://$url"
fi


}



