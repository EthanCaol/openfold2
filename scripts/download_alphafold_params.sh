#!/bin/bash
set -e

if [[ $# -eq 0 ]]; then
    echo "Error: download directory must be provided as an input argument."
    exit 1
fi

if ! command -v aria2c &>/dev/null; then
    echo "Error: aria2c could not be found. Please install aria2c (sudo apt install aria2)."
    exit 1
fi

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/params"
SOURCE_URL="https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar"
BASENAME=$(basename "${SOURCE_URL}")

mkdir -p "${ROOT_DIR}"
aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 "${SOURCE_URL}" --dir="${ROOT_DIR}"
tar -x --verbose --file="${ROOT_DIR}/${BASENAME}" \
    --directory="${ROOT_DIR}" --preserve-permissions
rm "${ROOT_DIR}/${BASENAME}"
