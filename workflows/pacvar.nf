/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_pacvar_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BAM_SNP_VARIANT_CALLING as BAM_SNP_VARIANT_CALLING    } from '../subworkflows/local/bam_snp_variant_calling'
include { BAM_SV_VARIANT_CALLING as BAM_SV_VARIANT_CALLING      } from '../subworkflows/local/bam_sv_variant_calling'
include { REPEAT_CHARACTERIZATION as REPEAT_CHARACTERIZATION    } from '../subworkflows/local/repeat_characterization'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { LIMA                                                  } from '../modules/nf-core/lima/main'
include { PBTK_PBMERGE                                          } from '../modules/nf-core/pbtk/pbmerge/main'
include { DEEPVARIANT_RUNDEEPVARIANT                            } from '../modules/nf-core/deepvariant/rundeepvariant/main'
include { SAMTOOLS_INDEX                                        } from '../modules/nf-core/samtools/index/main'
include { SAMTOOLS_SORT                                         } from '../modules/nf-core/samtools/sort/main'
include { GATK4_HAPLOTYPECALLER                                 } from '../modules/nf-core/gatk4/haplotypecaller/main'
include { PBMM2_ALIGN                                           } from '../modules/nf-core/pbmm2/align/main'
include { HIPHASE as HIPHASE_SNP                                } from '../modules/nf-core/hiphase/main'
include { HIPHASE as HIPHASE_SV                                 } from '../modules/nf-core/hiphase/main'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PACVAR {

    take:
    ch_samplesheet
    fasta
    fasta_fai
    dict
    dbsnp
    dbsnp_tbi
    intervals

    main:
    ch_versions = Channel.empty()

    // demultiplexing
    if (!params.skip_demultiplexing) {
        ch_barcode = Channel.value(file(params.barcodes))
        LIMA(ch_samplesheet, ch_barcode)
        ch_versions = ch_versions.mix(LIMA.out.versions)

        ch_lima = LIMA.out.bam
            .flatMap{ meta, sampleBams ->
                //seperate samples
                sampleBams.collect { bam -> [meta, bam] }
            }
            .map{ meta, bam ->
                //change metadata to reflect demultiplexed barcode
                [[id: bam.baseName], bam]
            }

            pbmm2_input_ch = ch_lima
    }

    // align input directly (skipping demultiplexing phase)
    else {
        pbmm2_input_ch = ch_samplesheet
    }

    // filter input based on workflow type
    pbmm2_input_filter_ch = pbmm2_input_ch.filter { meta, bam ->
        if (params.workflow == 'wgs') {
            return meta.type == 'hifi'
        }
        else if (params.workflow == 'repeat') {
            return meta.type in ['hifi', 'fail']
        }
        else {
            return false
        }
    }

    PBMM2_ALIGN(pbmm2_input_filter_ch, fasta)
    ch_versions = ch_versions.mix(PBMM2_ALIGN.out.versions)


    // merge hifi and fail bams for repeat workflow
    if (params.workflow == 'wgs') {
        samtools_input_ch = PBMM2_ALIGN.out.bam
            .map { meta, bam -> [meta-meta.subMap('type'), bam] }
    }
    else if (params.workflow == 'repeat') {
        ch_bams = PBMM2_ALIGN.out.bam
            .map { meta, bam -> [meta-meta.subMap('type'), bam] }
            .groupTuple()

        // get samples with hifi and fail reads
        ch_to_merge = ch_bams
            .filter { meta, bams -> bams.size() > 1 }
            .map { meta, bams -> [meta, bams] }

        // get samples with only hifi reads
        ch_no_merge = ch_bams
            .filter { meta, bams -> bams.size() == 1 }
            .map { meta, bams -> [meta, bams[0]] }

        PBTK_PBMERGE(ch_to_merge)
        ch_versions = ch_versions.mix(PBTK_PBMERGE.out.versions)
        ch_merged = PBTK_PBMERGE.out.bam

        ch_no_merge
            .mix(ch_merged)
            .set { samtools_input_ch }
    }

    ///
    ch_samplesheet.view { it -> "ch_samplesheet: ${it}"}
    pbmm2_input_ch.view { it -> "pbmm2_input_ch: ${it}"}
    pbmm2_input_filter_ch.view { it -> "pbmm2_input_filter_ch: ${it}"}
    ch_bams.view { it -> "ch_bams: ${it}"}
    ch_to_merge.view { it -> "ch_to_merge: ${it}"}
    ch_no_merge.view { it -> "ch_no_merge: ${it}"}
    ch_merged.view { it -> "ch_merged: ${it}"}
    samtools_input_ch.view { it -> "samtools_input_ch: ${it}"}
    ///

    SAMTOOLS_SORT(samtools_input_ch, fasta)
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.bam)
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions)


    //join the bam and index based off the meta id (ensure correct order)
    bam_bai_ch = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.bai)
    ordered_bam_ch = bam_bai_ch.map { meta, bam, bai -> [meta, bam] }
    ordered_bai_ch = bam_bai_ch.map { meta, bam, bai -> [meta, bai] }

    //if whole genome sequencing call CNV and SV call the WGS workflow + phase
    if (params.workflow == 'wgs') {

        if (!params.skip_snp) {
            //gatk or deepvariant snp calling
            BAM_SNP_VARIANT_CALLING(ordered_bam_ch,
                ordered_bai_ch,
                fasta,
                fasta_fai,
                dict,
                dbsnp,
                dbsnp_tbi,
                intervals)

            ch_versions = ch_versions.mix(BAM_SNP_VARIANT_CALLING.out.versions)

            //join the bam and bai and vcf based off the meta id (ensure correct order)
            bam_bai_vcf_snp_ch = bam_bai_ch.join(BAM_SNP_VARIANT_CALLING.out.vcf_ch)

            orderd_bam_bai_vcf_tbi_snp = bam_bai_vcf_snp_ch
            .multiMap { meta, bam, bai, vcf, tbi ->
                bam_bai: [meta, bam, bai]
                vcf_tbi: [meta, vcf, tbi]
            }

            if (!params.skip_phase) {
                //phase snp files
                HIPHASE_SNP(orderd_bam_bai_vcf_tbi_snp.vcf_tbi,
                    orderd_bam_bai_vcf_tbi_snp.bam_bai,
                    fasta)
                ch_versions = ch_versions.mix(HIPHASE_SNP.out.versions)
            }
        }

        if (!params.skip_sv) {
            //pbsv structural variant calling
            BAM_SV_VARIANT_CALLING(ordered_bam_ch,
                ordered_bai_ch,
                fasta,
                fasta_fai)

            ch_versions = ch_versions.mix(BAM_SV_VARIANT_CALLING.out.versions)

            //join the bam and bai and vcf based off the meta id (ensure correct order)
            bam_bai_vcf_sv_ch = bam_bai_ch.join(BAM_SV_VARIANT_CALLING.out.vcf_ch)

            orderd_bam_bai_vcf_tbi_sv = bam_bai_vcf_sv_ch
            .multiMap { meta, bam, bai, vcf, tbi ->
                bam_bai: [meta, bam, bai]
                vcf_tbi: [meta, vcf, tbi]
            }

            //phase sv files
            if (!params.skip_phase) {
                HIPHASE_SV( orderd_bam_bai_vcf_tbi_sv.vcf_tbi,
                    orderd_bam_bai_vcf_tbi_sv.bam_bai,
                    fasta)

                ch_versions = ch_versions.mix(HIPHASE_SV.out.versions)
            }
        }
    }

    if (params.workflow == 'repeat') {
        // characterize repeats
        REPEAT_CHARACTERIZATION(ordered_bam_ch,
            ordered_bai_ch,
            fasta,
            fasta_fai,
            intervals)

        ch_versions = ch_versions.mix(REPEAT_CHARACTERIZATION.out.versions)
    }

    // MODULE: MultiQC
    ch_multiqc_files = Channel.empty()

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  + 'pipeline_software_' +  'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
