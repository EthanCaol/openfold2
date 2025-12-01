
# 环境配置

```sh
git clone https://github.com/EthanCaol/openfold2.git
cd openfold2



# 安装 Bazel
sudo apt install apt-transport-https curl gnupg -y
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
sudo apt install -y bazel libaio-dev pigz aria2

# 安装 AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install && rm -rf awscliv2.zip aws




vi ~/.bashrc
export MAX_JOBS=12
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export TORCH_CUDA_ARCH_LIST="8.9" # 4070TS
export PYTHONWARNINGS="ignore::FutureWarning"



# conda remove -y --name openfold2 --all
mamba env create -f environment.yml
echo "conda activate openfold2" >> ~/.bashrc && source ~/.bashrc
pip install   

# 根据 PyTorch 和 CUDA 版本, 安装对应的 FlashAttention 版本
# https://github.com/Dao-AILab/flash-attention/releases
pip install 

# 下载第三方依赖和模型参数 (别挂代理)
proxy_on && bash scripts/install_third_party_dependencies.sh
proxy_off && bash scripts/download_alphafold_params.sh openfold/resources
proxy_off && bash scripts/download_openfold_params.sh openfold/resources
proxy_off && bash scripts/download_openfold_soloseq_params.sh openfold/resources
bash scripts/run_unit_tests.sh


proxy_off && bash scripts/download_alphafold_dbs.sh openfold/resources reduced_dbs
bash examples/monomer/inference.sh


