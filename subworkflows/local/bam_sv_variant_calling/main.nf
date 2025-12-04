
include { PBSV_DISCOVER     } from '../../../modules/nf-core/pbsv/discover/main'
include { PBSV_CALL         } from '../../../modules/nf-core/pbsv/call/main'
include { SAWFISH_DISCOVER  } from '../../../modules/nf-core/sawfish/discover/main'
include { BCFTOOLS_INDEX    } from '../../../modules/nf-core/bcftools/index/main'
include { TABIX_BGZIP       } from '../../../modules/nf-core/tabix/bgzip/main'


workflow BAM_SV_VARIANT_CALLING {
    take:
    sorted_bam
    sorted_bai
    fasta
    fasta_fai
    expected_cn_bed         // tuple val(meta4), path(bed) - for SAWFISH
    maf_vcf                 // tuple val(meta5), path(vcf) - for SAWFISH (optional)
    cnv_exclude_regions_bed // tuple val(meta6), path(bed) - for SAWFISH (optional)


    main:
    ch_versions = channel.empty()
    vcf_ch      = channel.empty()

    //call the structural variants
    if (params.sv_caller == 'pbsv') {
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
    }

    if (params.sv_caller == 'sawfish') {
        // SAWFISH workflow
        // Combine BAM and BAI into single tuple: [meta, bam, bai]
        sorted_bam_bai = sorted_bam.join(sorted_bai)
        SAWFISH_DISCOVER(
            sorted_bam_bai,
            fasta,
            expected_cn_bed,
            maf_vcf,
            cnv_exclude_regions_bed
        )

        // SAWFISH outputs BCF with .csi index already - just join them
        vcf_ch = SAWFISH_DISCOVER.out.candidate_sv_bcf
            .join(SAWFISH_DISCOVER.out.candidate_sv_bcf_csi)

        ch_versions = ch_versions.mix(SAWFISH_DISCOVER.out.versions)
    }

    emit:
    vcf_ch
    versions       = ch_versions

}

