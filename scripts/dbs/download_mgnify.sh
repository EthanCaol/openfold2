#!/bin/bash
set -e

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/mgnify"
SOURCE_URL="https://storage.googleapis.com/alphafold-databases/v2.3/mgy_clusters_2022_05.fa.gz"
BASENAME=$(basename "${SOURCE_URL}")
mkdir -p "${ROOT_DIR}"

if [ -f "${ROOT_DIR}/${BASENAME%.gz}" ]; then
    echo "| MGnify 数据库已存在"
    exit 0
fi

if [ -f "${ROOT_DIR}/${BASENAME}" ] && [ ! -f "${ROOT_DIR}/${BASENAME}.aria2" ]; then
    echo "| MGnify 数据库压缩包已下载完成"
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 \
        "${SOURCE_URL}" --dir="${ROOT_DIR}"
fi

echo "| 开始解压 MGnify 数据库"
cleanup() {
    echo "| 检测到中断, 正在清理临时文件"
    rm -f "${ROOT_DIR}/${BASENAME%.gz}"
    exit 1
}
trap cleanup INT TERM
pv "${ROOT_DIR}/${BASENAME}" | pigz -d -p 12 > "${ROOT_DIR}/${BASENAME%.gz}"
rm -f "${ROOT_DIR}/${BASENAME}"