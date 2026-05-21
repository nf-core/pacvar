include { FIBERTOOLSRS_PREDICTM6A                          } from '../../../modules/nf-core/fibertoolsrs/predictm6a/main'
include { FIBERTOOLSRS_ADDNUCLEOSOMES                      } from '../../../modules/nf-core/fibertoolsrs/addnucleosomes/main'
include { FIBERTOOLSRS_EXTRACT as FIBERTOOLSRS_EXTRACT_NUC } from '../../../modules/nf-core/fibertoolsrs/extract/main'
include { FIBERTOOLSRS_EXTRACT as FIBERTOOLSRS_EXTRACT_M6A } from '../../../modules/nf-core/fibertoolsrs/extract/main'
include { SAMTOOLS_INDEX                                   } from '../../../modules/nf-core/samtools/index/main'

workflow BAM_M6A_ADDNUCLEOSOMES_FIBERTOOLS {

    take:
    bam_ch
    m6a_predict_enable

    main:

    ch_fiberseq_bam = bam_ch.map { meta, bam -> [ meta + [file_name: bam.baseName], bam ] }

    if (m6a_predict_enable) {
        FIBERTOOLSRS_PREDICTM6A(ch_fiberseq_bam)
        ch_fiberseq_tagged_bam = FIBERTOOLSRS_PREDICTM6A.out.bam
    }
    else {
        FIBERTOOLSRS_ADDNUCLEOSOMES(ch_fiberseq_bam)
        ch_fiberseq_tagged_bam = FIBERTOOLSRS_ADDNUCLEOSOMES.out.bam
    }

    SAMTOOLS_INDEX(ch_fiberseq_tagged_bam)

    FIBERTOOLSRS_EXTRACT_NUC(
        ch_fiberseq_tagged_bam,
        'nuc'
    )

    FIBERTOOLSRS_EXTRACT_M6A(
        ch_fiberseq_tagged_bam,
        'm6a'
    )

    bam_bai_ch = ch_fiberseq_tagged_bam.join(SAMTOOLS_INDEX.out.index)

    emit:
    bam_bai = bam_bai_ch
    nuc_bed = FIBERTOOLSRS_EXTRACT_NUC.out.bed
    m6a_bed = FIBERTOOLSRS_EXTRACT_M6A.out.bed
}
