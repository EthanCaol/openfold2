#!/bin/bash
set -e

DOWNLOAD_DIR="${1}/openfold_soloseq_params"
mkdir -p "${DOWNLOAD_DIR}"
aws s3 cp --no-sign-request --region us-east-1 s3://openfold/openfold_soloseq_params/ "${DOWNLOAD_DIR}" --recursive
