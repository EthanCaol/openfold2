#!/bin/bash
# 网站链接: https://www.wwpdb.org/ftp/pdb-ftp-sites
set -e

DOWNLOAD_DIR="$1"
ROOT_DIR="${DOWNLOAD_DIR}/pdb_mmcif"
RAW_DIR="${ROOT_DIR}/raw"
MMCIF_DIR="${ROOT_DIR}/mmcif_files"
mkdir -p "${RAW_DIR}"

SNAPSHOT_DATE="20250101"

if [ -d "${MMCIF_DIR}" ]; then
    echo "| PDB mmCIF 数据库已存在"
else
    if [ -f "${ROOT_DIR}/commands.txt" ]; then
        echo "| 下载地址 commands.txt 已存在"
    else
        echo "| 生成下载地址 commands.txt (${SNAPSHOT_DATE}年度快照)"
        s5cmd --no-sign-request --json ls "s3://pdbsnapshots/${SNAPSHOT_DATE}/pub/pdb/data/structures/divided/mmCIF/*/*" |
            jq -r '.key' |
            awk -v dir="${RAW_DIR}/" '{rel = substr($0, index($0,"mmCIF/")+6); print "cp -s "$0" "dir rel}' \
                >"${ROOT_DIR}/commands.txt"
    fi

    echo "| 开始后台下载所有 mmCIF 文件"
    s5cmd --no-sign-request --numworkers 256 --retry-count 10 run "${ROOT_DIR}/commands.txt" >/dev/null 2>&1 &

    S5CMD_PID=$!
    echo "| 后台下载任务 PID: $S5CMD_PID"
    cleanup() {
        echo "| 检测到中断, 正在停止后台下载任务"
        kill $S5CMD_PID 2>/dev/null
        wait $S5CMD_PID 2>/dev/null
        exit 1
    }
    trap cleanup INT TERM

    LOGFILE="${ROOT_DIR}/s5cmd.log"
    s5cmd --no-sign-request --numworkers 256 --retry-count 10 run "${ROOT_DIR}/commands.txt" >"$LOGFILE" 2>&1 &

    S5CMD_PID=$!
    PREV_DONE=0
    TOTAL=$(wc -l <"${ROOT_DIR}/commands.txt") # 总文件数

    while kill -0 $S5CMD_PID 2>/dev/null; do
        sleep 5
        DONE=$(wc -l <"$LOGFILE")
        RATE=$(((DONE - PREV_DONE) / 5))

        if [ $RATE -gt 0 ]; then
            REMAIN_SEC=$(((TOTAL - DONE) / RATE))
            REMAIN_MIN=$((REMAIN_SEC / 60))
            REMAIN_SEC_MOD=$((REMAIN_SEC % 60))
            REMAIN_STR="${REMAIN_MIN}m ${REMAIN_SEC_MOD}s"
        else
            REMAIN_STR="计算中"
        fi

        PCT=$(awk -v d="$DONE" -v t="$TOTAL" 'BEGIN{printf "%.2f", (d/t)*100}')
        echo "[$(date '+%H:%M:%S')] $DONE/$TOTAL ($PCT%), 还需用时: ${REMAIN_STR}"
        PREV_DONE=$DONE
    done

    rm -f "$LOGFILE"

    echo "| 解压所有 mmCIF 文件"
    find "${RAW_DIR}/" -type f -iname "*.gz" -exec pigz -d -p 12 {} +

    echo "| 将所有 mmCIF 文件移动到同个目录中"
    mkdir -p "${MMCIF_DIR}"
    find "${RAW_DIR}" -type d -empty -delete
    for subdir in "${RAW_DIR}"/*; do
        mv "${subdir}/"*.cif "${MMCIF_DIR}"
    done
    find "${RAW_DIR}" -type d -empty -delete
fi

if [ -f "${ROOT_DIR}/obsolete.dat" ]; then
    echo "| obsolete.dat 遗弃条目已存在"
    exit 0
else
    aria2c --allow-overwrite=false --auto-file-renaming=false -x 16 -s 16 \
        "https://pdbsnapshots.s3-us-west-2.amazonaws.com/${SNAPSHOT_DATE}/pub/pdb/data/status/obsolete.dat" --dir="${ROOT_DIR}"
fi
