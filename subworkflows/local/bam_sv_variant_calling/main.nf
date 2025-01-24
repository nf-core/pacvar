include { PBSV_DISCOVER     } from '../../../modules/nf-core/pbsv/discover/main'
include { PBSV_CALL         } from '../../../modules/nf-core/pbsv/call/main'
include { BCFTOOLS_INDEX    } from '../../../modules/nf-core/bcftools/index/main'
include { TABIX_BGZIP       } from '../../../modules/nf-core/tabix/bgzip/main'

workflow BAM_SV_VARIANT_CALLING {
    take:
    sorted_bam
    sorted_bai
    fasta
    fasta_fai

    main:
    ch_versions = Channel.empty()

    //call the structural variants
    PBSV_DISCOVER(sorted_bam, fasta)
    PBSV_CALL(PBSV_DISCOVER.out.svsig, fasta)

    //zip and index
    TABIX_BGZIP(PBSV_CALL.out.vcf)
    BCFTOOLS_INDEX(TABIX_BGZIP.out.output)

    vcf_ch = TABIX_BGZIP.out.output.join(BCFTOOLS_INDEX.out.csi)

    ch_versions = ch_versions.mix(PBSV_DISCOVER.out.versions)
    ch_versions = ch_versions.mix(PBSV_CALL.out.versions)
    ch_versions = ch_versions.mix(TABIX_BGZIP.out.versions)
    ch_versions = ch_versions.mix(BCFTOOLS_INDEX.out.versions)

    emit:
    vcf_ch
    versions       = ch_versions

}
