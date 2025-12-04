#!/bin/bash
# Downloads and unzips the PDB SeqRes database for AlphaFold.
#
# Usage: bash download_pdb_seqres.sh /path/to/download/directory
set -e

if [[ $# -eq 0 ]]; then
    echo "Error: download directory must be provided as an input argument."
    exit 1
fi

if ! command -v aria2c &> /dev/null ; then
    echo "Error: aria2c could not be found. Please install aria2c (sudo apt install aria2)."
    exit 1
fi

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/pdb_seqres"
SOURCE_URL="ftp://ftp.wwpdb.org/pub/pdb/derived_data/pdb_seqres.txt"

mkdir -p "${ROOT_DIR}"
aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 "${SOURCE_URL}" --dir="${ROOT_DIR}"

# Keep only protein sequences.
grep --after-context=1 --no-group-separator '>.* mol:protein' "${ROOT_DIR}/pdb_seqres.txt" > "${ROOT_DIR}/pdb_seqres_filtered.txt"
mv "${ROOT_DIR}/pdb_seqres_filtered.txt" "${ROOT_DIR}/pdb_seqres.txt"
