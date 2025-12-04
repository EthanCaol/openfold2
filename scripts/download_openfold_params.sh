#!/bin/bash
# Downloads OpenFold parameters.
#
# Usage: bash download_openfold_params_huggingface.sh /path/to/download/directory
set -e

if [[ $# -eq 0 ]]; then
    echo "Error: download directory must be provided as an input argument."
    exit 1
fi

if ! command -v aws &> /dev/null ; then
    echo "Error: aws could not be found. Please install aws."
    exit 1
fi

DOWNLOAD_DIR="${1}/openfold_params"
mkdir -p "${DOWNLOAD_DIR}"
aws s3 cp --no-sign-request --region us-east-1 s3://openfold/openfold_params/ "${DOWNLOAD_DIR}" --recursive
