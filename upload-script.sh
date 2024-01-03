#!/bin/bash

if [[ "$#" == '0' ]]; then
    echo -e 'ERROR: No File Specified!' && exit 1
fi

while getopts ":gp" option; do
    case "${option}" in
        g)
            SERVER="gofile"
            ;;
        p)
            SERVER="pixeldrain"
            ;;
        *)
            echo "Invalid option: -$OPTARG. Use -g for Gofile or -p for Pixeldrain." >&2
            exit 1
            ;;
    esac
done

SERVER="${SERVER:-gofile}"

FILE="@$1"

if [[ "${SERVER}" == "gofile" ]]; then
    SERVER_URL="https://api.gofile.io/getServer"
    UPLOAD_URL="https://gofile.io/uploadFile"
    LINK_KEY=".data|.downloadPage"
elif [[ "${SERVER}" == "pixeldrain" ]]; then
    SERVER_URL="https://pixeldrain.com/api/file/"
    UPLOAD_URL="https://pixeldrain.com/api/file/"
    LINK_KEY="\"id\":\"[^\"]*\"" 
else
    echo "Invalid server option: ${SERVER}. Use -g for Gofile or -p for Pixeldrain." >&2
    exit 1
fi

SERVER=$(curl -s "${SERVER_URL}" | jq -r '.data|.server')
UPLOAD=$(curl -F file=${FILE} "${UPLOAD_URL}")
LINK=$(echo ${UPLOAD} | jq -r "${LINK_KEY}")

echo -e "\n\e[1;32m[✓] Uploaded successfully! \e[0m"
echo -e "\n\e[1;32m[✓] $LINK \e[0m"

echo " "
exit 1