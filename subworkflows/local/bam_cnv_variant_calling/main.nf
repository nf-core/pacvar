include { HIFICNV        } from '../../../modules/local/hificnv/main'
include { BCFTOOLS_INDEX } from '../../../modules/nf-core/bcftools/index/main'

workflow BAM_CNV_VARIANT_CALLING {
    
    take:
    bam_bai_maf     // channel: tuple val(meta), path(bam), path(bai), path(maf)
    fasta           // channel: tuple val(meta2), path(ref)
    exclude         // channel: tuple val(meta3), path(exclude)
    expected_cn     // channel: tuple val(meta4), path(expected_cn)
    
    main:
    ch_versions = Channel.empty()
    
    // Run HiFiCNV
    HIFICNV(
        bam_bai_maf,
        fasta,
        exclude,
        expected_cn
    )
    
    BCFTOOLS_INDEX(HIFICNV.out.vcf)
    // Join VCF with CSI index
    vcf_indexed_ch = HIFICNV.out.vcf.join(BCFTOOLS_INDEX.out.csi)

    ch_versions = ch_versions.mix(HIFICNV.out.versions)
    ch_versions = ch_versions.mix(BCFTOOLS_INDEX.out.versions)
    
    emit:
    vcf_indexed    = vcf_indexed_ch          // channel: tuple val(meta), path("*.vcf.gz"), path("*.vcf.gz.csi")
    versions       = ch_versions             // channel: path(versions.yml)
}