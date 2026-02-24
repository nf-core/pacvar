
include { PBSV_DISCOVER     } from '../../../modules/nf-core/pbsv/discover/main'
include { PBSV_CALL         } from '../../../modules/nf-core/pbsv/call/main'
include { SAWFISH_DISCOVER  } from '../../../modules/nf-core/sawfish/discover/main'
include { SAWFISH_JOINTCALL } from '../../../modules/nf-core/sawfish/jointcall/main'
include { BCFTOOLS_INDEX    } from '../../../modules/nf-core/bcftools/index/main'
include { TABIX_BGZIP       } from '../../../modules/nf-core/tabix/bgzip/main'


workflow BAM_SV_VARIANT_CALLING {
    take:
    sorted_bam              // tuple val(meta), path(bam)
    sorted_bai              // tuple val(meta), path(bai)
    fasta                   // tuple val(meta), path(ref)
    fasta_fai               // tuple val(meta), path(fai)
    expected_cn             // tuple val(meta), path(bed) - for SAWFISH
    maf_vcf                 // tuple val(meta), path(vcf) - for SAWFISH
    cnv_excluded_regions    // tuple val(meta), path(bed) - for SAWFISH


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
        sorted_bam_bai = sorted_bam.join(sorted_bai, by: 0)

        SAWFISH_DISCOVER(
            sorted_bam_bai,
            fasta,
            expected_cn,
            maf_vcf,
            cnv_excluded_regions
        )

        discover_bam_bai_joined = SAWFISH_DISCOVER.out.discover_dir
            .join(sorted_bam_bai, by: 0)

        SAWFISH_JOINTCALL(
            discover_bam_bai_joined.map { meta, discover_dir, bam, bai -> [meta, discover_dir] },
            fasta,
            discover_bam_bai_joined.map { meta, discover_dir, bam, bai -> [meta, bam, bai] },
            [[:], []]
        )
        // Call genotype SVs
        //SAWFISH_JOINTCALL(
        //    SAWFISH_DISCOVER.out.discover_dir,
        //    fasta,
        //   sorted_bam_bai,
        //    [[:], []]
        //)

        // VCF output with TBI index
        vcf_ch = SAWFISH_JOINTCALL.out.vcf.join(SAWFISH_JOINTCALL.out.tbi)

        ch_versions = ch_versions.mix(SAWFISH_DISCOVER.out.versions)
        ch_versions = ch_versions.mix(SAWFISH_JOINTCALL.out.versions)
    }

    emit:
    vcf_ch
    versions       = ch_versions
}
