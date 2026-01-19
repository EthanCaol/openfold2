
# 环境配置

```sh
git clone https://github.com/EthanCaol/openfold2.git
cd openfold2


# 安装 CUDA 12.8
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb && rm -rf cuda-keyring_1.1-1_all.deb
sudo apt update && sudo apt -y install cuda-toolkit-12-8 # 匹配 PyTorch

# 安装 Bazel
sudo apt install -y apt-transport-https
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


# 配置环境变量
vi ~/.bashrc
export MAX_JOBS=12
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export TORCH_CUDA_ARCH_LIST="8.9" # 4070TS

# 安装Python包
mamba install -y -f environment.yml
pip install -r requirements.txt

# 编译 attn_core_inplace_cuda
python setup.py build_ext --inplace
mv *.so "$(python -c "import site; print(site.getsitepackages()[0])")/"

# 将当前目录安装作为 openfold 包
echo "$PWD" > "$(python -c "import site; print(site.getsitepackages()[0])")/openfold.pth"

# deepspeed不想让torch的TORCH_CUDA_ARCH_LIST生效, 但是torch会警告
sed -i 's/os\.environ\["TORCH_CUDA_ARCH_LIST"\] = ""/# &/' \
    "${CONDA_PREFIX}/lib/python3.13/site-packages/deepspeed/ops/op_builder/builder.py"

# 下载第三方依赖和模型参数
proxy_on && bash scripts/install_third_party_dependencies.sh
proxy_off && bash scripts/download_alphafold_params.sh openfold/resources
proxy_off && bash scripts/download_openfold_params.sh openfold/resources
proxy_off && bash scripts/download_openfold_soloseq_params.sh openfold/resources

# 跑测试 (重启vscode后运行)
python3 -m unittest "$@"

# 下载数据库
bash scripts/dbs/download_alphafold_dbs.sh openfold/resources reduced_dbs
bash examples/monomer/inference.sh


python3 run_pretrained_openfold.py