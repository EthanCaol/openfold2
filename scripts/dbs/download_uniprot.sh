#!/bin/bash
set -e

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/uniprot"

TREMBL_SOURCE_URL="ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.fasta.gz"
TREMBL_BASENAME=$(basename "${TREMBL_SOURCE_URL}")
TREMBL_UNZIPPED_BASENAME="${TREMBL_BASENAME%.gz}"

SPROT_SOURCE_URL="ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz"
SPROT_BASENAME=$(basename "${SPROT_SOURCE_URL}")
SPROT_UNZIPPED_BASENAME="${SPROT_BASENAME%.gz}"
mkdir -p "${ROOT_DIR}"

if [ -f "${ROOT_DIR}/uniprot.fasta" ]; then
    echo "| Uniprot 数据库已存在"
    exit 0
fi

if [ -f "${ROOT_DIR}/${TREMBL_BASENAME}" ] && [ ! -f "${ROOT_DIR}/${TREMBL_BASENAME}.aria2" ]; then
    echo "| Uniprot TrEMBL 数据库压缩包已存在"
elif [ -f "${ROOT_DIR}/${TREMBL_UNZIPPED_BASENAME}" ]; then
    echo "| Uniprot TrEMBL 数据库已解压"
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 12 -s 12 "${TREMBL_SOURCE_URL}" --dir="${ROOT_DIR}"
fi

if [ -f "${ROOT_DIR}/${SPROT_BASENAME}" ] && [ ! -f "${ROOT_DIR}/${SPROT_BASENAME}.aria2" ]; then
    echo "| Uniprot SwissProt 数据库压缩包已存在"
elif [ -f "${ROOT_DIR}/${SPROT_UNZIPPED_BASENAME}" ]; then
    echo "| Uniprot SwissProt 数据库已解压"
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 12 -s 12 "${SPROT_SOURCE_URL}" --dir="${ROOT_DIR}"
fi

echo "| 开始解压 Uniprot TrEMBL 数据库"
pv -pterb "${ROOT_DIR}/${TREMBL_BASENAME}" | pigz -d -p 12 >"${ROOT_DIR}/${TREMBL_UNZIPPED_BASENAME}"
rm -f "${ROOT_DIR}/${TREMBL_BASENAME}"

echo "| 开始解压 Uniprot SwissProt 数据库"
pv -pterb "${ROOT_DIR}/${SPROT_BASENAME}" | pigz -d -p 12 >"${ROOT_DIR}/${SPROT_UNZIPPED_BASENAME}"
rm -f "${ROOT_DIR}/${SPROT_BASENAME}"

# 连接 TrEMBL 和 SwissProt, 重命名为 uniprot 并清理
cat "${ROOT_DIR}/${SPROT_UNZIPPED_BASENAME}" >>"${ROOT_DIR}/${TREMBL_UNZIPPED_BASENAME}"
mv "${ROOT_DIR}/${TREMBL_UNZIPPED_BASENAME}" "${ROOT_DIR}/uniprot.fasta"
rm -f "${ROOT_DIR}/${SPROT_UNZIPPED_BASENAME}"
