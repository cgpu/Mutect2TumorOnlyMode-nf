
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
    publishDir "$params.outdir/ValidateBamFiles", mode: 'copy'
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

process create_GenomicsDB {

    tag "all_the_vcfs"
    publishDir "$params.outdir/create_GenomicsDB_script", mode: 'copy'
    container "broadinstitute/gatk:latest"

    input:
    file('*.vcf.gz') from vcf_for_create_GenomicsDB_channel.collect()
    file(ref) from ref_for_create_GenomicsDB_channel
    file(ref_index) from ref_index_for_create_GenomicsDB_channel
    file(ref_dict) from ref_dict_for_create_GenomicsDB_channel
    file(intervals) from interval_create_GenomicsDB_channel

    output:
    file("create_GenomicsDB.sh") into results_channel
    file('*vcf.gz') into vcf_for_somatic_PoN_channel

    shell:
    '''
    echo -n "gatk GenomicsDBImport -R !{ref} --genomicsdb-workspace-path pon_db " > create_GenomicsDB.sh
    for vcf in $(ls *.vcf.gz); do
    echo -n "-V $vcf " >> create_GenomicsDB.sh
    done
    echo -n "-L !{intervals}" --merge-input-intervals >> create_GenomicsDB.sh
    bash create_GenomicsDB.sh
    '''
}

process create_somatic_PoN {
    
    tag "$af_only_gnomad_vcf"
    publishDir "$params.outdir/create_somatic_PoN", mode: 'copy'
    container "broadinstitute/gatk:latest"

    input:
    file("*") from vcf_for_somatic_PoN_channel.collect()
    file(af_only_gnomad_vcf) from af_only_gnomad_vcf_channel
    file(af_only_gnomad_vcf_idx) from af_only_gnomad_vcf_idx_channel
    file(ref) from ref_create_somatic_PoN
    file(ref_index) from ref_index_create_somatic_PoN
    file(ref_dict) from ref_dict_create_somatic_PoN

    output:
    file("pon.vcf.gz") into create_somatic_PoN_results_channel
    
    script:
    """
    gatk CreateSomaticPanelOfNormals \
    -R $ref \
    --germline-resource $af_only_gnomad_vcf \
    -V gendb://$pon_db \
    -O pon.vcf.gz  
    """
}