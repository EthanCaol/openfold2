#!/bin/bash
set -e

DOWNLOAD_DIR="$1"
DOWNLOAD_MODE="${2:-full_dbs}" # 默认下载 full_dbs
if [[ "${DOWNLOAD_MODE}" != full_dbs && "${DOWNLOAD_MODE}" != reduced_dbs ]]; then
    echo "DOWNLOAD_MODE ${DOWNLOAD_MODE} not recognized."
    exit 1
fi

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [[ "${DOWNLOAD_MODE}" = full_dbs ]]; then
    echo "| 🛠️ 开始准备 BFD"
    bash "${SCRIPT_DIR}/download_bfd.sh" "${DOWNLOAD_DIR}"
    echo -e "| ✨ BFD 数据库准备完成\n"
else
    echo "| 🛠️ 开始准备 Small BFD 数据库"
    bash "${SCRIPT_DIR}/download_bfd_small.sh" "${DOWNLOAD_DIR}"
    echo -e "| ✨ Small BFD 数据库准备完成\n"
fi

echo "| 🛠️ 开始准备 MGnify 数据库"
bash "${SCRIPT_DIR}/download_mgnify.sh" "${DOWNLOAD_DIR}"
echo -e "| ✨ MGnify 数据库准备完成\n"

echo "| 🛠️ 开始准备 PDB70 数据库"
bash "${SCRIPT_DIR}/download_pdb70.sh" "${DOWNLOAD_DIR}"
echo -e "| ✨ PDB70 数据库准备完成\n"

echo "| 🛠️ 开始准备 PDB mmCIF 数据库"
bash "${SCRIPT_DIR}/download_pdb_mmcif.sh" "${DOWNLOAD_DIR}"
echo -e "| ✨ PDB mmCIF 数据库准备完成\n"

echo "| 🛠️ 开始准备 Uniref30 数据库"
bash "${SCRIPT_DIR}/download_uniref30.sh" "${DOWNLOAD_DIR}"
echo -e "| ✨ Uniref30 数据库准备完成\n"

echo "| 🛠️ 开始准备 Uniref90 数据库"
bash "${SCRIPT_DIR}/download_uniref90.sh" "${DOWNLOAD_DIR}"
echo -e "| ✨ Uniref90 数据库准备完成\n"

echo "| 🛠️ 开始准备 UniProt 数据库"
bash "${SCRIPT_DIR}/download_uniprot.sh" "${DOWNLOAD_DIR}"
echo -e "| ✨ UniProt 数据库准备完成\n"

echo "| 🛠️ 开始准备 PDB SeqRes 数据库"
bash "${SCRIPT_DIR}/download_pdb_seqres.sh" "${DOWNLOAD_DIR}"
echo -e "| ✨ PDB SeqRes 数据库准备完成\n"

echo -e "| ✨ 所有数据库下载完成"
