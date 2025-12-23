#!/bin/bash

# 下载氨基酸键长数据
wget -N --no-check-certificate -P openfold/resources \
    https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

# 链接到测试数据目录
mkdir -p tests/test_data/alphafold/common
ln -rs openfold/resources/stereo_chemical_props.txt tests/test_data/alphafold/common

# 解压测试数据
gunzip -c tests/test_data/sample_feats.pickle.gz > tests/test_data/sample_feats.pickle

# 下载并设置CUTLASS路径
echo "Download CUTLASS, required for Deepspeed Evoformer attention kernel"
git clone https://github.com/NVIDIA/cutlass --branch v3.6.0 --depth 1
conda env config vars set CUTLASS_PATH="$PWD"/cutlass

# This setting is used to fix a worker assignment issue during data loading
conda env config vars set KMP_AFFINITY=none
