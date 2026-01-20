import os
import math
import time
import json
import torch
import random
import pickle
import logging
import argparse
import numpy as np

logging.basicConfig(format="  🔧 %(asctime)s %(levelname)s - %(message)s", datefmt="%H:%M:%S")
logger = logging.getLogger(__file__)
logger.setLevel(level=logging.INFO)

torch.set_float32_matmul_precision("high")  # TF32加速
torch.set_grad_enabled(False)

from openfold.config import model_config
from openfold.data import templates, feature_pipeline, data_pipeline
from openfold.data.tools import hhsearch, hmmsearch
from openfold.np import protein
from openfold.utils.script_utils import (
    load_models_from_command_line,
    parse_fasta,
    run_model,
    prep_output,
    relax_protein,
)
from openfold.utils.tensor_utils import tensor_tree_map
from openfold.utils.trace_utils import pad_feature_dict_seq, trace_model_

from scripts.precompute_embeddings import EmbeddingGenerator
from scripts.utils import add_data_args


TRACING_INTERVAL = 50


def precompute_alignments(tags, seqs, alignment_dir, args):
    for tag, seq in zip(tags, seqs):
        tmp_fasta_path = os.path.join(args.output_dir, f"tmp_{os.getpid()}.fasta")
        with open(tmp_fasta_path, "w") as fp:
            fp.write(f">{tag}\n{seq}")

        local_alignment_dir = os.path.join(alignment_dir, tag)

        if args.use_precomputed_alignments is None:
            logger.info(f"Generating alignments for {tag}...")

            os.makedirs(local_alignment_dir, exist_ok=True)

            if "multimer" in args.config_preset:
                template_searcher = hmmsearch.Hmmsearch(
                    binary_path=args.hmmsearch_binary_path,
                    hmmbuild_binary_path=args.hmmbuild_binary_path,
                    database_path=args.pdb_seqres_database_path,
                )
            else:
                template_searcher = hhsearch.HHSearch(
                    binary_path=args.hhsearch_binary_path,
                    databases=[args.pdb70_database_path],
                )

            # In seqemb mode, use AlignmentRunner only to generate templates
            if args.use_single_seq_mode:
                alignment_runner = data_pipeline.AlignmentRunner(
                    jackhmmer_binary_path=args.jackhmmer_binary_path,
                    uniref90_database_path=args.uniref90_database_path,
                    template_searcher=template_searcher,
                    no_cpus=args.cpus,
                )
                embedding_generator = EmbeddingGenerator()
                embedding_generator.run(tmp_fasta_path, alignment_dir)
            else:
                alignment_runner = data_pipeline.AlignmentRunner(
                    jackhmmer_binary_path=args.jackhmmer_binary_path,
                    hhblits_binary_path=args.hhblits_binary_path,
                    uniref90_database_path=args.uniref90_database_path,
                    mgnify_database_path=args.mgnify_database_path,
                    bfd_database_path=args.bfd_database_path,
                    uniref30_database_path=args.uniref30_database_path,
                    uniclust30_database_path=args.uniclust30_database_path,
                    uniprot_database_path=args.uniprot_database_path,
                    template_searcher=template_searcher,
                    use_small_bfd=args.bfd_database_path is None,
                    no_cpus=args.cpus,
                )

            alignment_runner.run(
                tmp_fasta_path,
                local_alignment_dir,
            )
        else:
            logger.info(f"Using precomputed alignments for {tag} at {alignment_dir}...")

        # Remove temporary FASTA file
        os.remove(tmp_fasta_path)


def round_up_seqlen(seqlen):
    return int(math.ceil(seqlen / TRACING_INTERVAL)) * TRACING_INTERVAL


def generate_feature_dict(
    tags,
    seqs,
    alignment_dir,
    data_processor,
    args,
):
    tmp_fasta_path = os.path.join(args.output_dir, f"tmp_{os.getpid()}.fasta")

    if "multimer" in args.config_preset:
        with open(tmp_fasta_path, "w") as fp:
            fp.write("\n".join([f">{tag}\n{seq}" for tag, seq in zip(tags, seqs)]))
        feature_dict = data_processor.process_fasta(
            fasta_path=tmp_fasta_path,
            alignment_dir=alignment_dir,
        )
    elif len(seqs) == 1:
        tag = tags[0]
        seq = seqs[0]
        with open(tmp_fasta_path, "w") as fp:
            fp.write(f">{tag}\n{seq}")

        local_alignment_dir = os.path.join(alignment_dir, tag)
        feature_dict = data_processor.process_fasta(
            fasta_path=tmp_fasta_path,
            alignment_dir=local_alignment_dir,
            seqemb_mode=args.use_single_seq_mode,
        )
    else:
        with open(tmp_fasta_path, "w") as fp:
            fp.write("\n".join([f">{tag}\n{seq}" for tag, seq in zip(tags, seqs)]))
        feature_dict = data_processor.process_multiseq_fasta(
            fasta_path=tmp_fasta_path,
            super_alignment_dir=alignment_dir,
        )

    # Remove temporary FASTA file
    os.remove(tmp_fasta_path)

    return feature_dict


def list_files_with_extensions(dir, extensions):
    return [f for f in os.listdir(dir) if f.endswith(extensions)]


def main(args):
    # 创建输出目录
    os.makedirs(args.output_dir, exist_ok=True)

    if args.config_preset.startswith("seq"):
        args.use_single_seq_mode = True

    config = model_config(
        args.config_preset,
        long_sequence_inference=args.long_sequence_inference,
        use_deepspeed_evoformer_attention=args.use_deepspeed_evoformer_attention,
        use_cuequivariance_attention=args.use_cuequivariance_attention,
        use_cuequivariance_multiplicative_update=args.use_cuequivariance_multiplicative_update,
        precision=args.precision,
        trt_mode=args.trt_mode,
        trt_engine_dir=args.trt_engine_dir,
        trt_num_profiles=args.trt_num_profiles,
        trt_optimization_level=args.trt_optimization_level,
        trt_max_sequence_len=args.trt_max_sequence_len,
    )

    if args.experiment_config_json:
        with open(args.experiment_config_json, "r") as f:
            custom_config_dict = json.load(f)
        config.update_from_flattened_dict(custom_config_dict)

    if args.trace_model:
        if not config.data.predict.fixed_size:
            raise ValueError("Tracing requires that fixed_size mode be enabled in the config")

    is_multimer = "multimer" in args.config_preset
    is_custom_template = "use_custom_template" in args and args.use_custom_template
    if is_custom_template:
        template_featurizer = templates.CustomHitFeaturizer(
            mmcif_dir=args.template_mmcif_dir,
            max_template_date="9999-12-31",  # just dummy, not used
            max_hits=-1,  # just dummy, not used
            kalign_binary_path=args.kalign_binary_path,
        )
    elif is_multimer:
        template_featurizer = templates.HmmsearchHitFeaturizer(
            mmcif_dir=args.template_mmcif_dir,
            max_template_date=args.max_template_date,
            max_hits=config.data.predict.max_templates,
            kalign_binary_path=args.kalign_binary_path,
            release_dates_path=args.release_dates_path,
            obsolete_pdbs_path=args.obsolete_pdbs_path,
        )
    else:
        template_featurizer = templates.HhsearchHitFeaturizer(
            mmcif_dir=args.template_mmcif_dir,
            max_template_date=args.max_template_date,
            max_hits=config.data.predict.max_templates,
            kalign_binary_path=args.kalign_binary_path,
            release_dates_path=args.release_dates_path,
            obsolete_pdbs_path=args.obsolete_pdbs_path,
        )
    data_processor = data_pipeline.DataPipeline(
        template_featurizer=template_featurizer,
    )
    if is_multimer:
        data_processor = data_pipeline.DataPipelineMultimer(
            monomer_data_pipeline=data_processor,
        )

    output_dir_base = args.output_dir
    random_seed = args.data_random_seed
    if random_seed is None:
        random_seed = random.randrange(2**32)

    np.random.seed(random_seed)
    torch.manual_seed(random_seed + 1)
    feature_processor = feature_pipeline.FeaturePipeline(config.data)
    if not os.path.exists(output_dir_base):
        os.makedirs(output_dir_base)
    if args.use_precomputed_alignments is None:
        alignment_dir = os.path.join(output_dir_base, "alignments")
    else:
        alignment_dir = args.use_precomputed_alignments

    tag_list = []
    seq_list = []
    for fasta_file in list_files_with_extensions(args.fasta_dir, (".fasta", ".fa")):
        # Gather input sequences
        fasta_path = os.path.join(args.fasta_dir, fasta_file)
        with open(fasta_path, "r") as fp:
            data = fp.read()

        tags, seqs = parse_fasta(data)

        if not is_multimer and len(tags) != 1:
            print(f"{fasta_path} contains more than one sequence but " f"multimer mode is not enabled. Skipping...")
            continue

        # assert len(tags) == len(set(tags)), "All FASTA tags must be unique"
        tag = "-".join(tags)

        tag_list.append((tag, tags))
        seq_list.append(seqs)

    seq_sort_fn = lambda target: sum([len(s) for s in target[1]])
    sorted_targets = sorted(zip(tag_list, seq_list), key=seq_sort_fn)
    feature_dicts = {}

    if is_multimer and args.openfold_checkpoint_path:
        raise ValueError("`openfold_checkpoint_path` was specified, but no OpenFold checkpoints are available for multimer mode")

    model_generator = load_models_from_command_line(
        config,
        args.model_device,
        args.openfold_checkpoint_path,
        args.jax_param_path,
        args.output_dir,
    )

    for model, output_directory in model_generator:
        cur_tracing_interval = 0
        for (tag, tags), seqs in sorted_targets:
            output_name = f"{tag}_{args.config_preset}"
            if args.output_postfix is not None:
                output_name = f"{output_name}_{args.output_postfix}"

            # Does nothing if the alignments have already been computed
            precompute_alignments(tags, seqs, alignment_dir, args)

            feature_dict = feature_dicts.get(tag, None)
            if feature_dict is None:
                feature_dict = generate_feature_dict(
                    tags,
                    seqs,
                    alignment_dir,
                    data_processor,
                    args,
                )

                if args.trace_model:
                    n = feature_dict["aatype"].shape[-2]
                    rounded_seqlen = round_up_seqlen(n)
                    feature_dict = pad_feature_dict_seq(
                        feature_dict,
                        rounded_seqlen,
                    )

                feature_dicts[tag] = feature_dict
            processed_feature_dict = feature_processor.process_features(feature_dict, mode="predict", is_multimer=is_multimer)

            processed_feature_dict = {k: torch.as_tensor(v, device=args.model_device) for k, v in processed_feature_dict.items()}

            if args.trace_model:
                if rounded_seqlen > cur_tracing_interval:
                    logger.info(f"Tracing model at {rounded_seqlen} residues...")
                    t = time.perf_counter()
                    trace_model_(model, processed_feature_dict)
                    tracing_time = time.perf_counter() - t
                    logger.info(f"Tracing time: {tracing_time}")
                    cur_tracing_interval = rounded_seqlen

            out = run_model(
                model,
                processed_feature_dict,
                tag,
                args.output_dir,
            )

            # Toss out the recycling dimensions --- we don't need them anymore
            processed_feature_dict = tensor_tree_map(lambda x: x[..., -1].cpu().numpy(), processed_feature_dict)
            out = tensor_tree_map(lambda x: x.cpu().numpy(), out)

            unrelaxed_protein = prep_output(
                out,
                processed_feature_dict,
                feature_dict,
                feature_processor,
                args.config_preset,
                args.multimer_ri_gap,
                args.subtract_plddt,
            )

            unrelaxed_file_suffix = "_unrelaxed.pdb"
            if args.cif_output:
                unrelaxed_file_suffix = "_unrelaxed.cif"
            unrelaxed_output_path = os.path.join(output_directory, f"{output_name}{unrelaxed_file_suffix}")

            with open(unrelaxed_output_path, "w") as fp:
                if args.cif_output:
                    fp.write(protein.to_modelcif(unrelaxed_protein))
                else:
                    fp.write(protein.to_pdb(unrelaxed_protein))

            logger.info(f"Output written to {unrelaxed_output_path}...")

            if not args.skip_relaxation:
                # Relax the prediction.
                logger.info(f"Running relaxation on {unrelaxed_output_path}...")
                relax_protein(
                    config,
                    args.model_device,
                    unrelaxed_protein,
                    output_directory,
                    output_name,
                    args.cif_output,
                )

            if args.save_outputs:
                output_dict_path = os.path.join(output_directory, f"{output_name}_output_dict.pkl")
                with open(output_dict_path, "wb") as fp:
                    pickle.dump(out, fp, protocol=pickle.HIGHEST_PROTOCOL)

                logger.info(f"Model output written to {output_dict_path}...")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "fasta_dir",
        type=str,
        help="推理序列的FASTA文件目录, 每个文件包含一个序列",
    )
    parser.add_argument(
        "template_mmcif_dir",
        type=str,
        help="模板文件的mmCIF目录",
    )
    parser.add_argument(
        "--use_precomputed_alignments",
        type=str,
        default=None,
        help="对齐文件目录 (如果提供, 则跳过对齐计算, 并忽略数据库路径参数)",
    )
    parser.add_argument(
        "--use_custom_template",
        action="store_true",
        default=False,
        help="是否使用 template_mmcif_dir 参数提供的 mmcif 作为模板输入",
    )
    parser.add_argument(
        "--use_single_seq_mode",
        action="store_true",
        default=False,
        help="是否使用单序列嵌入而非MSA进行推理",
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default=os.getcwd(),
        help="预测结果输出目录",
    )
    parser.add_argument(
        "--model_device",
        type=str,
        default="cuda",
        help="模型运行设备名称 (默认为'cuda')",
    )
    parser.add_argument(
        "--config_preset",
        type=str,
        default="model_1",
        help="模型配置预设名称, 定义在 openfold/config.py 中",
    )
    parser.add_argument(
        "--jax_param_path",
        type=str,
        default=None,
        help="JAX模型参数路径。如果为None，且openfold_checkpoint_path也为None，则根据模型名称自动从openfold/resources/params中选择参数",
    )
    parser.add_argument(
        "--openfold_checkpoint_path",
        type=str,
        default=None,
        help="OpenFold检查点路径。可以是DeepSpeed检查点目录或.pt文件",
    )
    parser.add_argument(
        "--save_outputs",
        action="store_true",
        default=False,
        help="是否保存所有模型输出，包括嵌入等",
    )
    parser.add_argument(
        "--cpus",
        type=int,
        default=4,
        help="用于运行对齐工具的CPU数量",
    )
    parser.add_argument(
        "--preset",
        type=str,
        default="full_dbs",
        choices=("reduced_dbs", "full_dbs"),
        help="预设数据库选项，影响对齐搜索所用的数据库集",
    )
    parser.add_argument(
        "--output_postfix",
        type=str,
        default=None,
        help="预测结果文件名的后缀",
    )
    parser.add_argument(
        "--data_random_seed",
        type=int,
        default=42,
        help="用于数据处理的随机种子 (默认为42)",
    )
    parser.add_argument(
        "--skip_relaxation",
        action="store_true",
        default=False,
        help="是否跳过结构放松步骤",
    )
    parser.add_argument(
        "--multimer_ri_gap",
        type=int,
        default=200,
        help="多序列之间的残基索引偏移量，如果提供的话",
    )
    parser.add_argument(
        "--trace_model",
        action="store_true",
        default=False,
        help="是否将模型的部分转换为TorchScript。显著提高运行速度，但会增加编译时间。适用于大批量任务。",
    )
    parser.add_argument(
        "--subtract_plddt",
        action="store_true",
        default=False,
        help="是否在B因子列输出 (100 - pLDDT) 而非pLDDT本身",
    )
    parser.add_argument(
        "--long_sequence_inference",
        action="store_true",
        default=False,
        help="启用选项以减少内存使用，代价是速度，帮助更长的序列适应GPU内存，详情见README",
    )
    parser.add_argument(
        "--cif_output",
        action="store_true",
        default=False,
        help="是否以ModelCIF格式输出预测模型，而非默认的PDB格式",
    )
    parser.add_argument(
        "--experiment_config_json",
        default="",
        help="用于覆盖配置设置的自定义配置值的json文件路径",
    )
    parser.add_argument(
        "--use_deepspeed_evoformer_attention",
        action="store_true",
        default=False,
        help="是否使用DeepSpeed evoformer注意力层。环境中必须安装deepspeed。",
    )
    parser.add_argument(
        "--use_cuequivariance_attention",
        action="store_true",
        default=False,
        help="是否使用cuEquivariance内核进行注意力计算。",
    )
    parser.add_argument(
        "--use_cuequivariance_multiplicative_update",
        action="store_true",
        default=False,
        help="是否使用cuEquivariance内核进行三角乘法更新计算。",
    )
    parser.add_argument(
        "--trt_mode",
        type=str,
        default=None,
        help="build = Build engine; run = Run engine; None = Disable TRT",
    )
    parser.add_argument(
        "--trt_engine_dir",
        type=str,
        default=None,
        help="Absolute path to directory containing .onnx and .plan files",
    )
    parser.add_argument(
        "--precision",
        type=str,
        default="tf32",
        help="tf32 | fp32 | fp16 | bf16",
    )
    parser.add_argument(
        "--trt_max_sequence_len",
        type=int,
        default=640,
        help="Maximum sequence length supported by TRT, default=640",
    )
    parser.add_argument(
        "--trt_num_profiles",
        type=int,
        default=1,
        help="1 = Single profile[50-800]; 2 = [50-200][200-800]; 4 = [50-100]; [100-200]; [200-400]; [400-800]",
    )
    parser.add_argument(
        "--trt_optimization_level",
        type=int,
        default=3,
        help="Allowed values: 0 to 5",
    )
    add_data_args(parser)
    args = parser.parse_args()

    # 根据配置预设选择默认参数路径
    if args.jax_param_path is None and args.openfold_checkpoint_path is None:
        args.jax_param_path = os.path.join("openfold", "resources", "params", "params_" + args.config_preset + ".npz")

    main(args)
