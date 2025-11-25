
# 环境配置

```sh
# conda remove -y --name openfold2 --all
echo "export TORCH_CUDA_ARCH_LIST=\"8.9\"" >> ~/.bashrc && source ~/.bashrc
echo "export MAX_JOBS=16" >> ~/.bashrc && source ~/.bashrc
echo "export PYTHONWARNINGS=\"ignore::FutureWarning\"" >> ~/.bashrc && source ~/.bashrc
sudo apt-get install -y libaio-dev

mamba env create -n openfold2 -f environment.yml -y
echo "conda activate openfold2" >> ~/.bashrc && source ~/.bashrc
pip install deepspeed==0.14.5 dm-tree==0.1.6 git+https://github.com/NVIDIA/dllogger.git

# https://github.com/Dao-AILab/flash-attention/releases/tag/v2.8.3
wget https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.3/flash_attn-2.8.3+cu12torch2.5cxx11abiFALSE-cp310-cp310-linux_x86_64.whl
pip install flash_attn-2.8.3+cu12torch2.5cxx11abiFALSE-cp310-cp310-linux_x86_64.whl

bash scripts/install_third_party_dependencies.sh
bash scripts/download_alphafold_params.sh openfold/resources
bash scripts/download_openfold_soloseq_params.sh openfold/resources
bash scripts/download_openfold_params.sh openfold/resources

bash scripts/run_unit_tests.sh