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

include { BAM_SNP_VARIANT_CALLING           } from '../subworkflows/local/bam_snp_variant_calling'
include { BAM_SV_VARIANT_CALLING            } from '../subworkflows/local/bam_sv_variant_calling'
include { BAM_CNV_VARIANT_CALLING           } from '../subworkflows/local/bam_cnv_variant_calling'
include { REPEAT_CHARACTERIZATION           } from '../subworkflows/local/repeat_characterization'
include { BAM_M6A_ADDNUCLEOSOMES_FIBERTOOLS } from '../subworkflows/local/bam_m6a_addnucleosomes_fibertools'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { VCF_ANNOTATE_ENSEMBLVEP as VCF_ANNOTATE_ENSEMBLVEP_SNP  } from '../subworkflows/nf-core/vcf_annotate_ensemblvep/main'
include { VCF_ANNOTATE_ENSEMBLVEP as VCF_ANNOTATE_ENSEMBLVEP_SV   } from '../subworkflows/nf-core/vcf_annotate_ensemblvep/main'
include { VCF_ANNOTATE_ENSEMBLVEP as VCF_ANNOTATE_ENSEMBLVEP_CNV  } from '../subworkflows/nf-core/vcf_annotate_ensemblvep/main'
include { LIMA                                                    } from '../modules/nf-core/lima/main'
include { PBTK_PBMERGE                                            } from '../modules/nf-core/pbtk/pbmerge/main'
include { SAMTOOLS_INDEX                                          } from '../modules/nf-core/samtools/index/main'
include { SAMTOOLS_SORT                                           } from '../modules/nf-core/samtools/sort/main'
include { PBMM2_ALIGN                                             } from '../modules/nf-core/pbmm2/align/main'
include { HIPHASE                                                 } from '../modules/nf-core/hiphase/main'
include { PBCPGTOOLS_ALIGNEDBAMTOCPGSCORES                        } from '../modules/nf-core/pbcpgtools/alignedbamtocpgscores/main'

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
    vep_cache             // [meta, cache]
    vep_cache_version
    vep_genome
    vep_species
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:
    ch_versions = channel.empty()

    // demultiplexing
    if (!params.skip_demultiplexing) {
        ch_barcode = channel.value(file(params.barcodes))
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

    fasta_with_fai_ch = fasta
        .combine(fasta_fai)
        .map { meta_fasta, fasta_file, meta_fai, fai_file -> [meta_fasta, fasta_file, fai_file] }
        .first()

    SAMTOOLS_SORT(samtools_input_ch, fasta_with_fai_ch, '')
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.bam)

    //join the bam and index based off the meta id (ensure correct order)
    bam_bai_ch = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.index)
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
        }

        if (!params.skip_sv) {
            //pbsv or sawfish structural variant calling
            // Prepare MAF VCF input only for SAWFISH when SNV calls are available
            if (params.sv_caller == 'sawfish' && !params.skip_snp) {
                // Create all three channels from bam_bai_vcf_snp_ch
                (sv_input_bam_ch, sv_input_bai_ch, sv_input_maf_ch) = bam_bai_vcf_snp_ch.multiMap { meta, bam, bai, vcf, _tbi ->
                    bam: [meta, bam]
                    bai: [meta, bai]
                    maf: [meta, vcf]
                }
            } else {
                // Use ordered channels when:
                // 1) sv_caller is not 'sawfish', OR
                // 2) sv_caller is 'sawfish' but skip_snp is true
                sv_input_bam_ch = ordered_bam_ch
                sv_input_bai_ch = ordered_bai_ch
                sv_input_maf_ch = channel.value([[:], []])
            }

            BAM_SV_VARIANT_CALLING(
                sv_input_bam_ch,
                sv_input_bai_ch,
                fasta,
                fasta_fai,
                expected_cn,
                sv_input_maf_ch,
                cnv_excluded_regions)

            ch_versions = ch_versions.mix(BAM_SV_VARIANT_CALLING.out.versions)

        }

        // Co-phase all available SNV and SV calls in a single HiPhase invocation.
        hiphase_enabled = !params.skip_phase && (!params.skip_snp || !params.skip_sv)
        if (hiphase_enabled) {
            hiphase_input_ch = bam_bai_ch

            if (!params.skip_snp) {
                hiphase_input_ch = hiphase_input_ch.join(BAM_SNP_VARIANT_CALLING.out.vcf_ch)
            }
            else {
                hiphase_input_ch = hiphase_input_ch.map { meta, bam, bai ->
                    [meta, bam, bai, [], []]
                }
            }

            if (!params.skip_sv) {
                hiphase_input_ch = hiphase_input_ch.join(BAM_SV_VARIANT_CALLING.out.vcf_ch)
            }
            else {
                hiphase_input_ch = hiphase_input_ch.map { meta, bam, bai, snv, snv_index ->
                    [meta, bam, bai, snv, snv_index, [], []]
                }
            }

            hiphase_input_ch = hiphase_input_ch.map { meta, bam, bai, snv, snv_index, sv, sv_index ->
                [meta, bam, bai, snv, snv_index, sv, sv_index, []]
            }

            HIPHASE(
                hiphase_input_ch,
                fasta_with_fai_ch,
                true,  // output haplotagged BAM and its index
                true, // summary file
                true, // blocks file
                true,  // phasing statistics
                true, // haplotag assignments
                'csv'  // file format
            )

            phased_bam_bai_ch = HIPHASE.out.bams.join(HIPHASE.out.bams_indexes)
        }

        // Annotate SNVs only after the combined HiPhase stage has completed.
        if (!params.skip_snp && !params.skip_ensemblvep) {
            ch_snv_vcf_to_vep = hiphase_enabled
                ? HIPHASE.out.vcfs
                : BAM_SNP_VARIANT_CALLING.out.vcf_ch.map { meta, vcf, _tbi -> [meta, vcf] }

            VCF_ANNOTATE_ENSEMBLVEP_SNP (
                ch_snv_vcf_to_vep.map { meta, vcf -> [meta + [file_name: vcf.baseName - '.vcf'], vcf, []] }, // [meta, vcf, [custom files]]
                fasta,
                vep_genome,
                vep_species,
                vep_cache_version,
                vep_cache,
                []
            )
        }

        // Annotate SVs only after the combined HiPhase stage has completed.
        if (!params.skip_sv && !params.skip_ensemblvep) {
            ch_sv_vcf_to_vep = hiphase_enabled
                ? HIPHASE.out.sv_vcfs
                : BAM_SV_VARIANT_CALLING.out.vcf_ch.map { meta, vcf, _tbi -> [meta, vcf] }

            VCF_ANNOTATE_ENSEMBLVEP_SV (
                ch_sv_vcf_to_vep.map { meta, vcf -> [meta + [file_name: vcf.baseName - '.vcf'], vcf, []] }, // [meta, vcf, [custom files]]
                fasta,
                vep_genome,
                vep_species,
                vep_cache_version,
                vep_cache,
                []
            )
        }

        if (!params.skip_hificnv) {
            // Use phased alignments and phased SNV calls for minor-allele-frequency information  when HiPhase ran.
            if (hiphase_enabled && !params.skip_snp) {
                cnv_input_bam_bai_maf_ch = phased_bam_bai_ch
                    .join(HIPHASE.out.vcfs)
            }
            // HiPhase ran without SNV calls (SV-only): use the phased BAM/BAI and no MAF VCF.
            else if (hiphase_enabled) {
                cnv_input_bam_bai_maf_ch = phased_bam_bai_ch.map { meta, bam, bai ->
                    [meta, bam, bai, []]
                }
            }
            // HiPhase did not run, but SNV calls exist: use the original BAM/BAI and unphased SNV VCF.
            else if (!params.skip_snp) {
                cnv_input_bam_bai_maf_ch = bam_bai_vcf_snp_ch.map { meta, bam, bai, vcf, _tbi ->
                    [meta, bam, bai, vcf]
                }
            }
            // Neither HiPhase nor SNV calls are available: use the original BAM/BAI and no MAF VCF.
            else {
                cnv_input_bam_bai_maf_ch = bam_bai_ch.map { meta, bam, bai ->
                    [meta, bam, bai, []]
                }
            }

            BAM_CNV_VARIANT_CALLING(
                cnv_input_bam_bai_maf_ch.map { meta, bam, bai, vcf -> [meta + [file_name: bam.baseName], bam, bai, vcf] },
                fasta,
                expected_cn,
                cnv_excluded_regions
            )
            ch_versions = ch_versions.mix(BAM_CNV_VARIANT_CALLING.out.versions)
            ch_cnv_vcf = BAM_CNV_VARIANT_CALLING.out.vcf_indexed.map { meta, vcf, _tbi -> [meta, vcf] }

            if (!params.skip_ensemblvep) {
                VCF_ANNOTATE_ENSEMBLVEP_CNV (
                    ch_cnv_vcf.map { meta, vcf -> [meta + [file_name: vcf.baseName - '.vcf'], vcf, []] }, // [meta, vcf, [custom files]]
                    fasta,
                    vep_genome,
                    vep_species,
                    vep_cache_version,
                    vep_cache,
                    []
                )
            }
        }

        // CpG methylation scoring with pbcpgtools
        if (!params.skip_cpg) {
            cpg_bam_bai_ch = hiphase_enabled ? phased_bam_bai_ch : bam_bai_ch

            // Call pbcpgtools alignedbamtocpgscores
            PBCPGTOOLS_ALIGNEDBAMTOCPGSCORES(
                cpg_bam_bai_ch.map { meta, bam, bai -> [meta + [file_name: bam.baseName], bam, bai] }
                )

            ch_versions = ch_versions.mix(PBCPGTOOLS_ALIGNEDBAMTOCPGSCORES.out.versions)
        }

        if (!params.skip_fiberseq) {
            fiberseq_bam_ch = hiphase_enabled ? HIPHASE.out.bams : ordered_bam_ch

            BAM_M6A_ADDNUCLEOSOMES_FIBERTOOLS(
                fiberseq_bam_ch,
                !params.skip_m6A_predict
            )
        }
    }

    if (params.workflow == 'repeat') {
        // characterize repeats
        REPEAT_CHARACTERIZATION(
            ordered_bam_ch,
            ordered_bai_ch,
            fasta,
            fasta_fai,
            intervals)

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

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'pacvar_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'pacvar'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
