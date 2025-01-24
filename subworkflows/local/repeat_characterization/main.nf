include { TRGT_GENOTYPE     } from '../../../modules/nf-core/trgt/genotype'
include { TRGT_PLOT         } from '../../../modules/nf-core/trgt/plot'
include { BCFTOOLS_SORT     } from '../../../modules/nf-core/bcftools/sort/main'
include { BCFTOOLS_INDEX    } from '../../../modules/nf-core/bcftools/index/main'
include { SAMTOOLS_SORT     } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX    } from '../../../modules/nf-core/samtools/index/main'

workflow  REPEAT_CHARACTERIZATION{

    take:
    sorted_bam
    sorted_bai
    fasta
    fasta_fai
    bed
    repeat_id
    karyotype

    main:
    ch_versions = Channel.empty()

    karyotype_value = karyotype.map { tuple -> tuple[1] }

    bam_bai_ch = sorted_bam.join(sorted_bai).combine(karyotype_value)

    TRGT_GENOTYPE(bam_bai_ch,
        fasta,
        fasta_fai,
        bed)

    //sort the resulting spanning bam
    SAMTOOLS_SORT(TRGT_GENOTYPE.out.bam,
        fasta)

    //index the resulting bam
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.bam)

    //sort the resulting vcf
    BCFTOOLS_SORT(TRGT_GENOTYPE.out.vcf)

    //Index the VCF file
    BCFTOOLS_INDEX(BCFTOOLS_SORT.out.vcf)

    bam_bai_ch = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.bai)
    bam_bai_vcf_tbi_ch =  SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.bai).join(BCFTOOLS_SORT.out.vcf).join(BCFTOOLS_INDEX.out.csi)

    //add the repeat id to the channel
    repeat_values = repeat_id.map { tuple -> tuple[1] }

    bam_bai_vcf_tbi_repeat_ch = bam_bai_vcf_tbi_ch.combine(repeat_values)

    //plot the vcf file -- for a specified id
    TRGT_PLOT(bam_bai_vcf_tbi_repeat_ch,
        fasta,
        fasta_fai,
        bed)

    ch_versions = ch_versions.mix(TRGT_GENOTYPE.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions)
    ch_versions = ch_versions.mix(BCFTOOLS_SORT.out.versions)
    ch_versions = ch_versions.mix(TRGT_PLOT.out.versions)

    emit:
    versions       = ch_versions
}
