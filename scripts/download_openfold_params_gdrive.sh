#!/bin/bash
# Downloads and unzips OpenFold parameters from Google Drive. Alternative to
# the HuggingFace version.
#
# Usage: bash download_openfold_params_gdrive.sh /path/to/download/directory
set -e

if [[ $# -eq 0 ]]; then
    echo "Error: download directory must be provided as an input argument."
    exit 1
fi

FILE_ID="1GVzZA2nbdBbz6TKydvzquhfELJ3Movnb"
FILENAME="openfold_params_07_22.tar.gz"

download_from_gdrive() {
    FILE_ID="$1"
    OUT_DIR="$2"
    MSG=$(wget \
         --quiet \
         --save-cookies /tmp/cookies_$$.txt \
         --keep-session-cookies \
         --no-check-certificate \
         "https://docs.google.com/uc?export=download&id=${FILE_ID}" \
         -O- \
    )
    CONFIRM=$(echo $MSG | sed -rn "s/.*confirm=([0-9A-Za-z_]+).*/\1\n/p")
    FILENAME=$(echo $MSG | sed -e "s/.*<a href=\"\/open?id=${FILE_ID}\">\(.*\)<\/a> (.*/\1/")
    FILEPATH="${OUT_DIR}/${FILENAME}"
    wget \
        --quiet \
        --load-cookies /tmp/cookies_$$.txt \
        "https://docs.google.com/uc?export=download&confirm=${CONFIRM}&id=${FILE_ID}" \
        -O "${FILEPATH}"
    rm /tmp/cookies_$$.txt
    echo $FILEPATH
}

DOWNLOAD_DIR="$1"
mkdir -p "${DOWNLOAD_DIR}"
DOWNLOAD_PATH=$(download_from_gdrive $FILE_ID "${DOWNLOAD_DIR}")

DOWNLOAD_FILENAME=$(basename "${DOWNLOAD_PATH}")
if [[ $FILENAME != $DOWNLOAD_FILENAME ]]; then
    echo "Error: Downloaded filename ${DOWNLOAD_FILENAME} does not match expected filename ${FILENAME}"
    rm "${DOWNLOAD_PATH}"
    exit
fi

tar --extract --verbose --file="${DOWNLOAD_PATH}" \
  --directory="${DOWNLOAD_DIR}" --preserve-permissions
rm "${DOWNLOAD_PATH}"
