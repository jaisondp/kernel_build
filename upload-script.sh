#!/bin/bash

if [[ "$#"  ==  '0' ]]; then
echo  -e 'ERROR: No File Specified!' && exit 1
fi

FILE="@$1"
SERVER=$(curl -s https://api.gofile.io/getServer | jq -r '.data|.server')
UPLOAD=$(curl -F file=${FILE} https://${SERVER}.gofile.io/uploadFile)
LINK=$(echo $UPLOAD | jq -r '.data|.downloadPage')

echo "\n\e[1;32m[✓] Uploaded successfully! \e[0m"
echo "\n\e[1;32m[✓] $LINK \e[0m"
echo " "
exit 1