#!/bin/bash
#
# Copyright 2021 DeepMind Technologies Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Downloads and unzips the MGnify database for AlphaFold.
#
# Usage: bash download_mgnify.sh /path/to/download/directory
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
ROOT_DIR="${DOWNLOAD_DIR}/mgnify"
# Mirror of:
# ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/peptide_database/2022_05/mgy_clusters.fa.gz
SOURCE_URL="https://storage.googleapis.com/alphafold-databases/v2.3/mgy_clusters_2022_05.fa.gz"
BASENAME=$(basename "${SOURCE_URL}")

# 如果文件已经存在, 则跳过
if [ -f "${ROOT_DIR}/${BASENAME%.gz}" ]; then
    echo "| MGnify 数据库已经存在, 跳过下载"
    exit 0
fi

mkdir --parents "${ROOT_DIR}"

# 如果压缩包已经存在, 并且没有控制文件(.aria2), 则跳过下载
if [ -f "${ROOT_DIR}/${BASENAME}" ] && [ ! -f "${ROOT_DIR}/${BASENAME}.aria2" ]; then
    echo "| MGnify 数据库压缩包已经下载完成, 跳过下载"
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 "${SOURCE_URL}" --dir="${ROOT_DIR}"
fi

echo "| 开始解压 MGnify 数据库"
pigz -d -p 8 "${ROOT_DIR}/${BASENAME}"