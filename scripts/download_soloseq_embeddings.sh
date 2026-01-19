#!/bin/bash
# Usage: bash download_soloseq_embeddings.sh /path/to/download/directory
set -e

DOWNLOAD_DIR="${1}/soloseq_embeddings"
mkdir -p "${DOWNLOAD_DIR}"
aws s3 cp --no-sign-request --region us-east-1 s3://openfold/soloseq_embeddings/ "${DOWNLOAD_DIR}" --recursive
