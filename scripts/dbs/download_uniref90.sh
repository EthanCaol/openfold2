#!/bin/bash
set -e

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/uniref90"
SOURCE_URL="ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/uniref90.fasta.gz"
BASENAME=$(basename "${SOURCE_URL}")
mkdir -p "${ROOT_DIR}"

if [ -f "${ROOT_DIR}/uniref90.fasta" ]; then
    echo "| Uniref90 数据库已存在"
    exit 0
fi

if [ -f "${ROOT_DIR}/${BASENAME}" ] && [ ! -f "${ROOT_DIR}/${BASENAME}.aria2" ]; then
    echo "| Uniref90 数据库压缩包已存在"
    exit 0
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 "${SOURCE_URL}" --dir="${ROOT_DIR}"
fi

echo "| 开始解压 Uniref90 数据库"
pv -pterb "${ROOT_DIR}/${BASENAME}" | pigz -d -p 12 >"${ROOT_DIR}/${BASENAME%.gz}"
rm -f "${ROOT_DIR}/${BASENAME}"

