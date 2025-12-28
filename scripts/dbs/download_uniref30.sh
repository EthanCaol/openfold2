#!/bin/bash
set -e

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/uniref30"
SOURCE_URL="https://storage.googleapis.com/alphafold-databases/v2.3/UniRef30_2021_03.tar.gz"
BASENAME=$(basename "${SOURCE_URL}")
mkdir -p "${ROOT_DIR}"

if [ -f "${ROOT_DIR}/UniRef30_2021_03_a3m.ffdata" ]; then
    echo "| Uniref30 数据库已存在"
    exit 0
fi

if [ -f "${ROOT_DIR}/${BASENAME}" ] && [ ! -f "${ROOT_DIR}/${BASENAME}.aria2" ]; then
    echo "| Uniref30 数据库压缩包已存在"
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 "${SOURCE_URL}" --dir="${ROOT_DIR}"
fi

echo "| 开始解压 Uniref30 数据库"
pv "${ROOT_DIR}/${BASENAME}" | tar -xzf - -C "${ROOT_DIR}"
rm -f "${ROOT_DIR}/${BASENAME}"
