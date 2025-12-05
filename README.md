
# 环境配置

```sh
git clone https://github.com/EthanCaol/openfold2.git
cd openfold2


# 安装 CUDA 12.8
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb && rm -rf cuda-keyring_1.1-1_all.deb
sudo apt update && sudo apt -y install cuda-toolkit-12-8 # 匹配 PyTorch

# 安装 Bazel
sudo apt install apt-transport-https curl gnupg -y
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
sudo apt update && sudo apt install -y bazel libaio-dev pigz aria2

# 安装 AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install && rm -rf awscliv2.zip aws

# 安装 s5cmd
wget https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_Linux-64bit.tar.gz
mkdir s5cmd_temp && tar -xvf s5cmd_2.3.0_Linux-64bit.tar.gz -C s5cmd_temp
sudo mv s5cmd_temp/s5cmd /usr/local/bin/s5cmd
rm -rf s5cmd_temp s5cmd_2.3.0_Linux-64bit.tar.gz


# 安装 Miniconda
mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm -rf ~/miniconda3/miniconda.sh
~/miniconda3/bin/conda init bash
eval "$(/home/ethan/miniconda3/bin/conda shell.bash hook)"
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
conda config --add channels conda-forge
conda install -y mamba ncurses -c conda-forge
mamba shell init --shell bash --root-prefix=~/.local/share/mamba


# 配置环境变量
vi ~/.bashrc
export MAX_JOBS=12
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export TORCH_CUDA_ARCH_LIST="8.9" # 4070TS

# 安装Python包
mamba install -y -f environment.yml
pip install -r requirements.txt

# 下载第三方依赖和模型参数 (别挂代理)
proxy_on && bash scripts/install_third_party_dependencies.sh
proxy_off && bash scripts/download_alphafold_params.sh openfold/resources
proxy_off && bash scripts/download_openfold_params.sh openfold/resources
proxy_off && bash scripts/download_openfold_soloseq_params.sh openfold/resources
bash scripts/run_unit_tests.sh

proxy_off && bash scripts/dbs/download_alphafold_dbs.sh openfold/resources reduced_dbs
bash examples/monomer/inference.sh


