#!/bin/bash
# Downloads and unzips OpenFold parameters.
#
# Usage: bash download_openfold_params_huggingface.sh /path/to/download/directory
set -e

if [[ $# -eq 0 ]]; then
    echo "Error: download directory must be provided as an input argument."
    exit 1
fi

URL="https://huggingface.co/nz/OpenFold"

DOWNLOAD_DIR="${1}/openfold_params/"
mkdir -p "${DOWNLOAD_DIR}"
git clone $URL "${DOWNLOAD_DIR}"
rm -rf "${DOWNLOAD_DIR}/.git"
