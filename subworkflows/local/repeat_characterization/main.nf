include { TRGT_GENOTYPE     } from '../../../modules/nf-core/trgt/genotype'
include { TRGT_PLOT         } from '../../../modules/nf-core/trgt/plot'
include { BCFTOOLS_SORT     } from '../../../modules/nf-core/bcftools/sort/main'
include { BCFTOOLS_INDEX    } from '../../../modules/nf-core/bcftools/index/main'
include { SAMTOOLS_SORT as SAMTOOLS_SORT_TRGT     } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_TRGT    } from '../../../modules/nf-core/samtools/index/main'


workflow  REPEAT_CHARACTERIZATION{

    take:
    sorted_bam
    sorted_bai
    fasta
    fasta_fai
    bed

    main:
    ch_versions = channel.empty()

    bam_bai_ch = sorted_bam
        .join(sorted_bai)
        .map{ meta, bam, bai -> [meta, bam, bai, meta.karyotype] }

    TRGT_GENOTYPE(bam_bai_ch,
        fasta,
        fasta_fai,
        bed)

    //sort the resulting spanning bam
    SAMTOOLS_SORT_TRGT(TRGT_GENOTYPE.out.bam,
        fasta, '')

    //index the resulting bam
    SAMTOOLS_INDEX_TRGT(SAMTOOLS_SORT_TRGT.out.bam)

    //sort the resulting vcf
    BCFTOOLS_SORT(TRGT_GENOTYPE.out.vcf)

    //index the VCF file
    BCFTOOLS_INDEX(BCFTOOLS_SORT.out.vcf)

    bam_bai_ch = SAMTOOLS_SORT_TRGT.out.bam.join(SAMTOOLS_INDEX_TRGT.out.bai)
    bam_bai_vcf_tbi_ch =  SAMTOOLS_SORT_TRGT.out.bam.join(SAMTOOLS_INDEX_TRGT.out.bai).join(BCFTOOLS_SORT.out.vcf).join(BCFTOOLS_INDEX.out.csi)

    //add repeat_id to channel
    bam_bai_vcf_tbi_repeat_ch = bam_bai_vcf_tbi_ch.map { meta, bam, bai, vcf, tbi -> [meta, bam, bai, vcf, tbi, meta.repeat_id] }

    //plot the vcf file -- for a specified id
    TRGT_PLOT(bam_bai_vcf_tbi_repeat_ch,
        fasta,
        fasta_fai,
        bed)

    // NOTE: all TRGT and SAMTOOLS modules are updated to version topic
    ch_versions = ch_versions.mix(BCFTOOLS_SORT.out.versions.first())

    emit:
    versions       = ch_versions
}
