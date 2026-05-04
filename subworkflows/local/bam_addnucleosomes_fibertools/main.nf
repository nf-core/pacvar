include { FIBERTOOLSRS_ADDNUCLEOSOMES  } from '../../../modules/nf-core/fibertoolsrs/addnucleosomes/main'
include { FIBERTOOLSRS_EXTRACT         } from '../../../modules/nf-core/fibertoolsrs/extract/main'
include { SAMTOOLS_INDEX               } from '../../../modules/nf-core/samtools/index/main'

workflow BAM_ADDNUCLEOSOMES_FIBERTOOLS {

    take:
    bam_ch

    main:
    ch_versions = channel.empty()

    FIBERTOOLSRS_ADDNUCLEOSOMES(
        bam_ch.map { meta, bam -> [ meta + [file_name: bam.baseName], bam ] }
    )

    SAMTOOLS_INDEX(FIBERTOOLSRS_ADDNUCLEOSOMES.out.bam)

    FIBERTOOLSRS_EXTRACT(
        FIBERTOOLSRS_ADDNUCLEOSOMES.out.bam.map { meta, bam -> [ meta, bam, 'nuc' ] }
    )

    bam_bai_ch = FIBERTOOLSRS_ADDNUCLEOSOMES.out.bam.join(SAMTOOLS_INDEX.out.index)

    ch_versions = ch_versions.mix(FIBERTOOLSRS_ADDNUCLEOSOMES.out.versions)
    ch_versions = ch_versions.mix(FIBERTOOLSRS_EXTRACT.out.versions)

    emit:
    bam_bai = bam_bai_ch
    nuc_bed = FIBERTOOLSRS_EXTRACT.out.bed
    versions = ch_versions
}
