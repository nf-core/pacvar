include { FIBERTOOLSRS_ADDNUCLEOSOMES                          } from '../../../modules/nf-core/fibertoolsrs/addnucleosomes/main'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_FIBERTOOLSRS_BAM    } from '../../../modules/nf-core/samtools/index/main'

workflow BAM_ADDNUCLEOSOMES_FIBERTOOLS {

    take:
    bam_ch

    main:
    ch_versions = channel.empty()

    FIBERTOOLSRS_ADDNUCLEOSOMES(
        bam_ch.map { meta, bam -> [ meta + [file_name: bam.baseName], bam ] }
    )

    SAMTOOLS_INDEX_FIBERTOOLSRS_BAM(FIBERTOOLSRS_ADDNUCLEOSOMES.out.bam)

    bam_bai_ch = FIBERTOOLSRS_ADDNUCLEOSOMES.out.bam.join(SAMTOOLS_INDEX_FIBERTOOLSRS_BAM.out.bai)

    ch_versions = ch_versions.mix(FIBERTOOLSRS_ADDNUCLEOSOMES.out.versions)

    emit:
    bam_bai = bam_bai_ch
    versions = ch_versions
}
