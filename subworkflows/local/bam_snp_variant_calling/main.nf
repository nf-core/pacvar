include { GATK4_HAPLOTYPECALLER      } from '../../../modules/nf-core/gatk4/haplotypecaller/main'
include { DEEPVARIANT_RUNDEEPVARIANT } from '../../../modules/nf-core/deepvariant/rundeepvariant/main'

workflow BAM_SNP_VARIANT_CALLING {
    take:
    sorted_bam
    sorted_bai
    fasta
    fasta_fai
    dict
    dbsnp
    dbsnp_tbi
    intervals

    main:
    ch_versions = Channel.empty()

    intervals_path = intervals.map{metadata, interval -> [interval]}
    //deepvariant
    if (params.snv_caller == 'deepvariant') {
        deepvar_input_ch = sorted_bam.join(sorted_bai).combine(intervals_path)
            .map{metadata, bam, bai, interval ->
            [metadata, bam, bai, interval]
        }

        DEEPVARIANT_RUNDEEPVARIANT(deepvar_input_ch,
            fasta,
            fasta_fai,
            [[], []],
            [[], []]
            )
        vcf_ch = DEEPVARIANT_RUNDEEPVARIANT.out.vcf.join(DEEPVARIANT_RUNDEEPVARIANT.out.vcf_tbi)
        ch_versions = ch_versions.mix(DEEPVARIANT_RUNDEEPVARIANT.out.versions)
    }

    //gatk4_haplotypecaller
    if (params.snv_caller == 'gatk4') {
        gatk4_input_ch = sorted_bam.join(sorted_bai).combine(intervals_path)
            .map{metadata, bam, bai, interval ->
                [metadata, bam, bai, interval, []]
        }

        GATK4_HAPLOTYPECALLER(gatk4_input_ch,
            fasta,
            fasta_fai,
            dict,
            dbsnp.map{it -> [[:], it]},
            dbsnp_tbi.map{it -> [[:], it]}
            )

        vcf_ch = GATK4_HAPLOTYPECALLER.out.vcf.join(GATK4_HAPLOTYPECALLER.out.tbi)
        ch_versions = ch_versions.mix(GATK4_HAPLOTYPECALLER.out.versions)

    }

    emit:
    vcf_ch
    versions       = ch_versions
}
