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
include { BAM_SV_VARIANT_CALLING  } from '../subworkflows/local/bam_sv_variant_calling'
include { BAM_CNV_VARIANT_CALLING } from '../subworkflows/local/bam_cnv_variant_calling'
include { REPEAT_CHARACTERIZATION as REPEAT_CHARACTERIZATION    } from '../subworkflows/local/repeat_characterization'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { LIMA                                                           } from '../modules/nf-core/lima/main'
include { PBTK_PBMERGE                                 } from '../modules/nf-core/pbtk/pbmerge/main'
include { DEEPVARIANT_RUNDEEPVARIANT                   } from '../modules/nf-core/deepvariant/rundeepvariant/main'
include { SAMTOOLS_INDEX                               } from '../modules/nf-core/samtools/index/main'
include { SAMTOOLS_SORT                                } from '../modules/nf-core/samtools/sort/main'
include { GATK4_HAPLOTYPECALLER                        } from '../modules/nf-core/gatk4/haplotypecaller/main'
include { PBMM2_ALIGN                                  } from '../modules/nf-core/pbmm2/align/main'
include { HIPHASE as HIPHASE_SNP                       } from '../modules/nf-core/hiphase/main'
include { HIPHASE as HIPHASE_SV                        } from '../modules/nf-core/hiphase/main'
include { PBCPGTOOLS_ALIGNEDBAMTOCPGSCORES             } from '../modules/nf-core/pbcpgtools/alignedbamtocpgscores/main'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_HIPHASE_SNP } from '../modules/nf-core/samtools/index/main'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_HIPHASE_SV  } from '../modules/nf-core/samtools/index/main'

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
    expected_cn
    cnv_excluded_regions

    main:
    ch_versions = channel.empty()

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
                def new_meta = meta + [id: bam.baseName]
                [new_meta, bam]
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

    SAMTOOLS_SORT(samtools_input_ch, fasta, '')
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.bam)
    // ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions.first())
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
                // phase snp files
                HIPHASE_SNP(orderd_bam_bai_vcf_tbi_snp.vcf_tbi,
                    orderd_bam_bai_vcf_tbi_snp.bam_bai,
                    fasta)
                ch_versions = ch_versions.mix(HIPHASE_SNP.out.versions)

                // Index the phased BAM from HIPHASE_SNP
                SAMTOOLS_INDEX_HIPHASE_SNP(HIPHASE_SNP.out.bam)
                ch_versions = ch_versions.mix(SAMTOOLS_INDEX_HIPHASE_SNP.out.versions)

                // channel for pbcpgtools_alignedbamtocpgscores
                bam_bai_snp_phased_ch = HIPHASE_SNP.out.bam.join(SAMTOOLS_INDEX_HIPHASE_SNP.out.bai)
            }
        }

        if (!params.skip_cnv) {
            // CNV calling with HiFiCNV (before or after DeepVariant/HiPhase)
            // Prepare channel and MAF input based on skip_snp and skip_phase parameters
            // bam_bam_maf_ch to be channel: tuple val(meta), path(bam), path(bai), path(vcf)
            if (!params.skip_snp && !params.skip_phase) {
                // define bam_bai_maf_ch
                // Use phased BAM, BAI, and VCF from HIPHASE_SNP
                bam_bai_maf_ch = bam_bai_ch
                    .join(HIPHASE_SNP.out.vcf)
                    .map { meta, bam, bai, vcf ->
                        [meta, bam, bai, vcf]
                    }
            } else if (!params.skip_snp && params.skip_phase) {
                // Use unphased BAM, BAI, and VCF from SNP calling
                bam_bai_maf_ch = bam_bai_vcf_snp_ch.map { meta, bam, bai, vcf, tbi ->
                    [meta, bam, bai, vcf]
                    }
            } else {
                // Skip SNP calling - use original BAM and BAI with empty VCF
                bam_bai_maf_ch = bam_bai_ch.map { meta, bam, bai ->
                    [meta, bam, bai, []]
                }
            }

            // Run HiFiCNV
            BAM_CNV_VARIANT_CALLING(
                bam_bai_maf_ch,
                fasta,
                expected_cn,
                cnv_excluded_regions
            )
            ch_versions = ch_versions.mix(BAM_CNV_VARIANT_CALLING.out.versions)
        }

        if (!params.skip_sv) {
            //pbsv or sawfish structural variant calling
            // Prepare MAF VCF input only for SAWFISH based on skip_snp and skip_phase parameters
            // maf_vcf_ch to be channel: tuple val(meta), path(vcf)
            if (params.sv_caller == 'sawfish') {
                // define maf_vcf_ch
                if (!params.skip_snp && !params.skip_phase) {
                    // Use phased VCF from HIPHASE_SNP (already [meta, vcf])
                    maf_vcf_ch = HIPHASE_SNP.out.vcf
                } else if (!params.skip_snp && params.skip_phase) {
                    // Use unphased VCF from SNP calling (extract just meta and vcf)
                    maf_vcf_ch = BAM_SNP_VARIANT_CALLING.out.vcf_ch.map { meta, vcf, tbi ->
                        [meta, vcf]
                    }
                } else {
                    // Skip SNP calling - empty VCF
                    maf_vcf_ch = channel.value([[:], []])
                }
            } else {
                // PBSV doesn't use MAF VCF - always empty
                maf_vcf_ch = channel.value([[:], []])
            }

            BAM_SV_VARIANT_CALLING(ordered_bam_ch,
                ordered_bai_ch,
                fasta,
                fasta_fai,
                expected_cn,
                maf_vcf_ch,
                cnv_excluded_regions)

            ch_versions = ch_versions.mix(BAM_SV_VARIANT_CALLING.out.versions)

            // join the bam and bai and vcf based off the meta id (ensure correct order)
            bam_bai_vcf_sv_ch = bam_bai_ch.join(BAM_SV_VARIANT_CALLING.out.vcf_ch)

            orderd_bam_bai_vcf_tbi_sv = bam_bai_vcf_sv_ch
            .multiMap { meta, bam, bai, vcf, tbi ->
                bam_bai: [meta, bam, bai]
                vcf_tbi: [meta, vcf, tbi]
            }

            //phase sv files
            if (!params.skip_phase) {
                HIPHASE_SV(orderd_bam_bai_vcf_tbi_sv.vcf_tbi,
                    orderd_bam_bai_vcf_tbi_sv.bam_bai,
                    fasta)

                ch_versions = ch_versions.mix(HIPHASE_SV.out.versions)

                // Index the phased BAM from HIPHASE_SV
                SAMTOOLS_INDEX_HIPHASE_SV(HIPHASE_SV.out.bam)
                ch_versions = ch_versions.mix(SAMTOOLS_INDEX_HIPHASE_SV.out.versions)
            }
        }

        // CpG methylation scoring with pbcpgtools
        if (!params.skip_cpg) {
            // Determine which BAM to use based on phasing and SNV calling
            if (!params.skip_snp && !params.skip_phase) {
                // Use phased BAM from HIPHASE_SNV
                cpg_bam_bai_ch = bam_bai_snp_phased_ch
            } else {
                // Use original sorted BAM
                cpg_bam_bai_ch = bam_bai_ch
            }

            // Call pbcpgtools alignedbamtocpgscores
            PBCPGTOOLS_ALIGNEDBAMTOCPGSCORES(
                cpg_bam_bai_ch)

            ch_versions = ch_versions.mix(PBCPGTOOLS_ALIGNEDBAMTOCPGSCORES.out.versions)
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
    ch_multiqc_files = channel.empty()

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  + 'pipeline_software_' +  'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
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
