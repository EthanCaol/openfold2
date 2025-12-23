import os
from setuptools import setup, find_packages
from torch.utils.cpp_extension import BuildExtension, CppExtension, CUDAExtension, CUDA_HOME


version_dependent_macros = [
    '-DVERSION_GE_1_1',
    '-DVERSION_GE_1_3',
    '-DVERSION_GE_1_5',
]

extra_cuda_flags = [
    '-std=c++17',
    '-maxrregcount=50',
    '-U__CUDA_NO_HALF_OPERATORS__',
    '-U__CUDA_NO_HALF_CONVERSIONS__',
    '--expt-relaxed-constexpr',
    '--expt-extended-lambda',
]


torch_cuda_arch_list = os.getenv('TORCH_CUDA_ARCH_LIST', default=None)
assert torch_cuda_arch_list is not None, "请设置环境变量 TORCH_CUDA_ARCH_LIST 来指定编译的CUDA计算能力, 例如 '8.0;8.9'"

compute_capabilities = set()
for arch in torch_cuda_arch_list.split(';'):
    major, minor = arch.strip().split('.')
    compute_capabilities.add((int(major), int(minor)))

cc_flag = []
for major, minor in list(compute_capabilities):
    cc_flag.extend([
        '-gencode',
        f'arch=compute_{major}{minor},code=sm_{major}{minor}',
    ])

print(f"当前cc_flag: {cc_flag}")
extra_cuda_flags += cc_flag

modules = [CUDAExtension(
    name="attn_core_inplace_cuda",
    sources=[
        "openfold/utils/kernel/csrc/softmax_cuda.cpp",
        "openfold/utils/kernel/csrc/softmax_cuda_kernel.cu",
    ],
    include_dirs=[
        os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            'openfold/utils/kernel/csrc/'
        )
    ],
    extra_compile_args={
        'cxx': ['-O3'] + version_dependent_macros,
        'nvcc': (
            ['-O3', '--use_fast_math'] +
            version_dependent_macros +
            extra_cuda_flags
        ),
    }
)]


setup(
    name='openfold',
    version='2.2.0',
    packages=find_packages(exclude=["tests", "scripts"]),
    include_package_data=True,
    package_data={
        "openfold": ['utils/kernel/csrc/*'],
        "": ["resources/stereo_chemical_props.txt"]
    },
    ext_modules=modules,
    cmdclass={'build_ext': BuildExtension},
)
