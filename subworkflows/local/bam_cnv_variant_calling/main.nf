include { HIFICNV        } from '../../../modules/nf-core/hificnv/main'
include { BCFTOOLS_INDEX } from '../../../modules/nf-core/bcftools/index/main'

workflow BAM_CNV_VARIANT_CALLING {

    take:
    sorted_bam_bai_maf    // channel: tuple val(meta), path(bam), path(bai), path(maf)
    fasta                 // channel: tuple val(meta), path(ref)
    expected_cn           // channel: tuple val(meta), path(expected_cn)
    cnv_excluded_regions  // channel: tuple val(meta), path(cnv_excluded_regions)

    main:
    ch_versions = channel.empty()

    // Run HiFiCNV
    HIFICNV(
        sorted_bam_bai_maf,
        fasta,
        cnv_excluded_regions,
        expected_cn
    )

    BCFTOOLS_INDEX(HIFICNV.out.vcf)
    // Join VCF with CSI index
    ch_vcf_indexed = HIFICNV.out.vcf.join(BCFTOOLS_INDEX.out.csi)

    ch_versions = ch_versions.mix(HIFICNV.out.versions)
    ch_versions = ch_versions.mix(BCFTOOLS_INDEX.out.versions)

    emit:
    vcf_indexed    = ch_vcf_indexed          // channel: tuple val(meta), path("*.vcf.gz"), path("*.vcf.gz.csi")
    versions       = ch_versions             // channel: path(versions.yml)
}
