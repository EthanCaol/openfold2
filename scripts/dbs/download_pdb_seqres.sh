#!/bin/bash
set -e

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/pdb_seqres"
SOURCE_URL="https://files.wwpdb.org/pub/pdb/derived_data/pdb_seqres.txt"

mkdir -p "${ROOT_DIR}"
aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 "${SOURCE_URL}" --dir="${ROOT_DIR}"

# Keep only protein sequences.
grep --after-context=1 --no-group-separator '>.* mol:protein' "${ROOT_DIR}/pdb_seqres.txt" > "${ROOT_DIR}/pdb_seqres_filtered.txt"
mv "${ROOT_DIR}/pdb_seqres_filtered.txt" "${ROOT_DIR}/pdb_seqres.txt"
