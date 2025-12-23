#!/bin/bash
set -e

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/params"
SOURCE_URL="https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar"
BASENAME=$(basename "${SOURCE_URL}")
mkdir -p "${ROOT_DIR}"

if [ -f "${ROOT_DIR}/params_model_1.npz" ]; then
    echo "| AlphaFold 参数已存在"
    exit 0
fi

if [ -f "${ROOT_DIR}/${BASENAME}" ] && [ ! -f "${ROOT_DIR}/${BASENAME}.aria2" ]; then
    echo "| AlphaFold 参数压缩包已存在"
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 "${SOURCE_URL}" --dir="${ROOT_DIR}"
fi

tar -xvpf "${ROOT_DIR}/${BASENAME}" -C "${ROOT_DIR}"
rm -f "${ROOT_DIR}/${BASENAME}"
