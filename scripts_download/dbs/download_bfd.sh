#!/bin/bash
set -e

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/bfd"
SOURCE_URL="https://storage.googleapis.com/alphafold-databases/casp14_versions/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz"
BASENAME=$(basename "${SOURCE_URL}")
mkdir -p "${ROOT_DIR}"

if [ -f "${ROOT_DIR}/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt" ]; then
    echo "| BFD 数据库已存在"
    exit 0
fi

if [ -f "${ROOT_DIR}/${BASENAME}" ] && [ ! -f "${ROOT_DIR}/${BASENAME}.aria2" ]; then
    echo "| BFD 数据库压缩包已存在"
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 \
        "${SOURCE_URL}" --dir="${ROOT_DIR}"
fi

echo "| 开始解压 BFD 数据库"
cleanup() {
    echo "| 检测到中断, 正在清理临时文件"
    rm -f "${ROOT_DIR}/${BASENAME%.tar.gz}"
    exit 1
}
trap cleanup INT TERM
pv "${ROOT_DIR}/${BASENAME}" | tar -xzf - -C "${ROOT_DIR}"
rm -f "${ROOT_DIR}/${BASENAME}"