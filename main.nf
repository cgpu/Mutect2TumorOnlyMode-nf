Channel
    .fromPath("${params.normal_bam_folder}/*.bam")
    .set {  bam_mutect2_tum_only_mode_channel }

Channel
    .fromPath("${params.normal_bam_folder}/*.bai")
    .set {  bai_mutect2_tum_only_mode_channel }

Channel
    .fromPath(params.ref)
    .into { ref_mutect2_tum_only_mode_channel ; ref_for_create_GenomicsDB_channel ; ref_create_somatic_PoN }

Channel
    .fromPath(params.ref_index)
    .into { ref_index_mutect2_tum_only_mode_channel ; ref_index_for_create_GenomicsDB_channel ; ref_index_create_somatic_PoN }

Channel
    .fromPath(params.ref_dict)
    .into { ref_dict_mutect2_tum_only_mode_channel ; ref_dict_for_create_GenomicsDB_channel ; ref_dict_create_somatic_PoN }

Channel
    .fromPath(params.interval_list)
    .into { interval_create_GenomicsDB_channel ; interval_list_mutect2_tum_only_mode_channel }

Channel
    .fromPath(params.af_only_gnomad_vcf)
    .set { af_only_gnomad_vcf_channel }

Channel
    .fromPath(params.af_only_gnomad_vcf_idx)
    .set { af_only_gnomad_vcf_idx_channel }


process run_mutect2_tumor_only_mode {

    tag "${normal_bam.simpleName.minus('_Normal')}"
    publishDir "MutectTumorOnlyModeResults", mode: 'copy'
    container "broadinstitute/gatk:latest"

    input:
    file(normal_bam) from bam_mutect2_tum_only_mode_channel
    file(normal_bai) from bai_mutect2_tum_only_mode_channel
    each file(ref) from ref_mutect2_tum_only_mode_channel
    each file(ref_index) from ref_index_mutect2_tum_only_mode_channel
    each file(ref_dict) from ref_dict_mutect2_tum_only_mode_channel
    each file(intervals) from interval_list_mutect2_tum_only_mode_channel

    output:
    file('*') into vcf_for_create_GenomicsDB_channel

    script:
    """
    gatk Mutect2 \
    -R ${ref} \
    -I ${normal_bam} -normal ${normal_bam.simpleName.minus('_Normal')} \
    --max-mnp-distance 0 \
    -O ${normal_bam.baseName}.vcf.gz \
    -L $intervals \
    --java-options '-DGATK_STACKTRACE_ON_USER_EXCEPTION=true'
    """
}