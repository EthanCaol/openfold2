
# 环境配置

```sh
git clone https://github.com/EthanCaol/openfold2.git
cd openfold2

# conda remove -y --name openfold2 --all
vi ~/.bashrc
export MAX_JOBS=16
export TORCH_CUDA_ARCH_LIST="8.9" # 4070Ti
export PYTHONWARNINGS="ignore::FutureWarning"
export CFLAGS="-I/usr/include"
export LDFLAGS="-L/usr/lib/x86_64-linux-gnu/ -laio"
function proxy_off(){
    unset http_proxy
    unset https_proxy
    unset no_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset NO_PROXY
}

sudo apt-get install -y libaio-dev pigz aria2
mamba env create -n openfold2 -f environment.yml -y
echo "conda activate openfold2" >> ~/.bashrc && source ~/.bashrc
pip install deepspeed==0.14.5 dm-tree==0.1.6 git+https://github.com/NVIDIA/dllogger.git
pip install cuequivariance_ops_torch_cu12 cuequivariance_torch

# https://github.com/Dao-AILab/flash-attention/releases/tag/v2.8.3
wget https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.3/flash_attn-2.8.3+cu12torch2.5cxx11abiFALSE-cp310-cp310-linux_x86_64.whl
pip install flash_attn-2.8.3+cu12torch2.5cxx11abiFALSE-cp310-cp310-linux_x86_64.whl
rm -rf flash_attn-2.8.3+cu12torch2.5cxx11abiFALSE-cp310-cp310-linux_x86_64.whl

# 下载第三方依赖和模型参数 (别挂代理)
proxy_off && bash scripts/install_third_party_dependencies.sh
proxy_off && bash scripts/download_alphafold_params.sh openfold/resources
proxy_off && bash scripts/download_openfold_params.sh openfold/resources
proxy_off && bash scripts/download_openfold_soloseq_params.sh openfold/resources
proxy_off && bash scripts/download_alphafold_dbs.sh openfold/resources reduced_dbs



bash scripts/run_unit_tests.sh
bash examples/monomer/inference.sh
